const DIRECTION_KEY_MASKS = {
  'KeyD': 0b0001, // Right
  'KeyA': 0b0010, // Left
  'KeyW': 0b0100, // Up
  'KeyS': 0b1000  // Down
};

const ACTION_KEY_MASKS = {
  'KeyK': 0b0001, // A
  'KeyJ': 0b0010, // B
  'KeyU': 0b0100, // Select
  'KeyI': 0b1000  // Start
};

const FRAME_WIDTH = 160;
const FRAME_HEIGHT = 144;
const FRAMEBUFFER_SIZE = FRAME_WIDTH * FRAME_HEIGHT * 4;
const AUDIO_BUFFER_OFFSET = FRAMEBUFFER_SIZE;
const AUDIO_BUFFER_SAMPLES = 1024 * 2;
const AUDIO_BUFFER_SIZE = AUDIO_BUFFER_SAMPLES * 4;
const MIN_REQUIRED_MEMORY = AUDIO_BUFFER_OFFSET + AUDIO_BUFFER_SIZE;
const WASM_PAGE_SIZE = 65536;
const M_CYCLE_NANOS = 953;
const MAX_CATCHUP_NANOS = 250_000_000;
const MAX_CYCLES_PER_STEP = 8_192;
const IMPORT_OBJECT = {
  spectest: {
    print_char: (_ch) => {},
  },
};

class Lunaboy {
  constructor() {
    this.directionKey = 0b0000;
    this.actionKey = 0b0000;
    this.running = false;
    this.loaded = false;
    this.memory = null;
    this.exports = null;
    this.throttleEnabled = true;
    this.startTimeNanos = 0;
    this.elapsedMachineNanos = 0;
    this.loopHandle = null;
    this.loopTick = this.emulationLoop.bind(this);
  }

  ensureMemory(requiredBytes) {
    const currentBytes = this.memory.buffer.byteLength;
    if (currentBytes >= requiredBytes) {
      return;
    }
    const growBytes = requiredBytes - currentBytes;
    const pages = Math.ceil(growBytes / WASM_PAGE_SIZE);
    this.memory.grow(pages);
  }

  async init() {
    const wasmResponse = await fetch('./lib.wasm');
    if (!wasmResponse.ok) {
      throw new Error('Failed to fetch wasm: ./lib.wasm');
    }
    const wasmBytes = new Uint8Array(await wasmResponse.arrayBuffer());
    const module = await WebAssembly.compile(wasmBytes);
    const instance = await WebAssembly.instantiate(module, IMPORT_OBJECT);
    this.exports = instance.exports;
    this.memory = instance.exports['moonbit.memory'];

    if (!this.exports.init_extern || !this.exports.run_frame_extern || !this.exports.run_cycles_extern || !this.exports.set_input_extern || !this.exports.pop_audio_extern) {
      throw new Error('Missing required exports: init_extern, run_frame_extern, run_cycles_extern, set_input_extern, pop_audio_extern');
    }
    if (!this.memory) {
      throw new Error('Missing export memory: moonbit.memory');
    }

  }

  resetClock() {
    this.startTimeNanos = performance.now() * 1_000_000;
    this.elapsedMachineNanos = 0;
  }

  setThrottleEnabled(enabled) {
    this.throttleEnabled = enabled;
    this.resetClock();
  }

  initWithRom(romData) {
    const romLength = romData.length;
    this.ensureMemory(Math.max(romLength, MIN_REQUIRED_MEMORY));
    const mem = new Uint8Array(this.memory.buffer);
    mem.set(romData, 0);
    this.exports.init_extern(romLength);
    this.loaded = true;
    this.resetClock();
  }

  postCopiedBuffer(type, View, offset, length) {
    const source = new View(this.memory.buffer, offset, length);
    const copied = new View(length);
    copied.set(source);
    postMessage({ type, data: copied.buffer }, [copied.buffer]);
  }

  sendFrame() {
    this.postCopiedBuffer('pixelData', Uint8ClampedArray, 0, FRAMEBUFFER_SIZE);
  }

  sendAudio(length) {
    this.postCopiedBuffer('audioData', Float32Array, AUDIO_BUFFER_OFFSET, length);
  }

  drainAudio() {
    const sampleLength = this.exports.pop_audio_extern();
    if (sampleLength > 0) {
      this.sendAudio(sampleLength);
    }
  }

  runUnthrottledFrame() {
    this.exports.run_frame_extern();
    this.drainAudio();
    this.sendFrame();
  }

  runThrottled() {
    const elapsedRealNanos = performance.now() * 1_000_000 - this.startTimeNanos;
    const targetNanos = Math.min(
      elapsedRealNanos,
      this.elapsedMachineNanos + MAX_CATCHUP_NANOS,
    );

    let frameCount = 0;
    while (targetNanos > this.elapsedMachineNanos) {
      const remainingNanos = targetNanos - this.elapsedMachineNanos;
      let cycles = Math.floor(remainingNanos / M_CYCLE_NANOS);
      if (cycles <= 0) {
        break;
      }

      cycles = Math.min(cycles, MAX_CYCLES_PER_STEP);
      frameCount += this.exports.run_cycles_extern(cycles);
      this.drainAudio();
      this.elapsedMachineNanos += cycles * M_CYCLE_NANOS;
    }

    if (frameCount > 0) {
      this.sendFrame();
    }
  }

  updateInput(code, pressed) {
    const directionKeyMask = DIRECTION_KEY_MASKS[code];
    const actionKeyMask = ACTION_KEY_MASKS[code];

    if (directionKeyMask) {
      if (pressed) {
        this.directionKey |= directionKeyMask;
      } else {
        this.directionKey &= ~directionKeyMask;
      }
    }

    if (actionKeyMask) {
      if (pressed) {
        this.actionKey |= actionKeyMask;
      } else {
        this.actionKey &= ~actionKeyMask;
      }
    }
  }

  start() {
    if (this.running) {
      return;
    }
    this.running = true;
    this.emulationLoop();
  }

  stop() {
    this.running = false;
    if (this.loopHandle !== null) {
      clearTimeout(this.loopHandle);
      this.loopHandle = null;
    }
  }

  emulationLoop() {
    if (!this.running) {
      return;
    }

    try {
      if (this.loaded) {
        this.exports.set_input_extern(this.directionKey, this.actionKey);
        if (this.throttleEnabled) {
          this.runThrottled();
        } else {
          this.runUnthrottledFrame();
        }
      }
    } catch (error) {
      this.stop();
      postMessage({ type: 'error', message: error.message });
      return;
    }

    this.loopHandle = setTimeout(this.loopTick, 0);
  }

  async loadPreInstalledRom(romName) {
    const romPath = `./roms/${romName}`;
    const response = await fetch(romPath);
    if (!response.ok) {
      throw new Error(`Failed to fetch rom: ${romPath}`);
    }
    this.initWithRom(new Uint8Array(await response.arrayBuffer()));
  }

  loadUploadedRom(data) {
    this.initWithRom(new Uint8Array(data));
  }
}

const lunaboy = new Lunaboy();

function postError(error) {
  postMessage({ type: 'error', message: error.message });
}

const messageHandlers = {
  async initLunaboy() {
    await lunaboy.init();
    postMessage({ type: 'initialized', message: 'ok' });
  },
  startLunaboy() {
    lunaboy.start();
  },
  stopLunaboy() {
    lunaboy.stop();
  },
  setThrottle(data) {
    lunaboy.setThrottleEnabled(data.enabled);
  },
  keydown(data) {
    lunaboy.updateInput(data.code, true);
  },
  keyup(data) {
    lunaboy.updateInput(data.code, false);
  },
  loadROM(data) {
    lunaboy.loadUploadedRom(data.data);
  },
  async loadPreInstalledRom(data) {
    await lunaboy.loadPreInstalledRom(data.romName);
  },
};

self.addEventListener('message', (event) => {
  const handler = messageHandlers[event.data.type];
  if (!handler) {
    return;
  }
  Promise.resolve(handler(event.data)).catch(postError);
});
