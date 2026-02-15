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
const WASM_PAGE_SIZE = 65536;
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
    this.bootrom = null;
    this.loopHandle = null;
  }

  async fetchBootrom() {
    const response = await fetch('./dmg_bootrom.bin');
    if (!response.ok) {
      throw new Error('Failed to fetch bootrom: ./dmg_bootrom.bin');
    }
    this.bootrom = new Uint8Array(await response.arrayBuffer());
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

    if (!this.exports.init_extern || !this.exports.run_frame_extern || !this.exports.set_input_extern) {
      throw new Error('Missing required exports: init_extern, run_frame_extern, set_input_extern');
    }
    if (!this.memory) {
      throw new Error('Missing export memory: moonbit.memory');
    }

    await this.fetchBootrom();
  }

  initWithRom(romData) {
    if (!this.bootrom) {
      throw new Error('Boot ROM is not loaded');
    }

    const bootromLength = this.bootrom.length;
    const romLength = romData.length;
    const totalLength = bootromLength + romLength;

    this.ensureMemory(totalLength);
    const mem = new Uint8Array(this.memory.buffer);
    mem.set(this.bootrom, 0);
    mem.set(romData, bootromLength);
    this.exports.init_extern(bootromLength, romLength);
    this.loaded = true;
  }

  runFrame() {
    if (!this.loaded) {
      return;
    }

    this.exports.set_input_extern(this.directionKey, this.actionKey);
    this.exports.run_frame_extern();
    const frame = new Uint8ClampedArray(
      this.memory.buffer,
      0,
      FRAMEBUFFER_SIZE,
    );
    const copied = new Uint8ClampedArray(FRAMEBUFFER_SIZE);
    copied.set(frame);
    postMessage({ type: 'pixelData', data: copied.buffer }, [copied.buffer]);
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
      this.runFrame();
    } catch (error) {
      this.stop();
      postMessage({ type: 'error', message: error.message });
      return;
    }

    this.loopHandle = setTimeout(this.emulationLoop.bind(this), 0);
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

self.addEventListener('message', async (event) => {
  if (event.data.type === 'initLunaboy') {
    try {
      await lunaboy.init();
      postMessage({ type: 'initialized', message: 'ok' });
    } catch (error) {
      postMessage({ type: 'error', message: error.message });
    }
  }

  if (event.data.type === 'startLunaboy') {
    try {
      lunaboy.start();
    } catch (error) {
      postMessage({ type: 'error', message: error.message });
    }
  }

  if (event.data.type === 'stopLunaboy') {
    lunaboy.stop();
  }

  if (event.data.type === 'keydown' || event.data.type === 'keyup') {
    const code = event.data.code;
    const directionKeyMask = DIRECTION_KEY_MASKS[code];
    const actionKeyMask = ACTION_KEY_MASKS[code];

    if (directionKeyMask) {
      if (event.data.type === 'keydown') {
        lunaboy.directionKey |= directionKeyMask;
      } else {
        lunaboy.directionKey &= ~directionKeyMask;
      }
    }

    if (actionKeyMask) {
      if (event.data.type === 'keydown') {
        lunaboy.actionKey |= actionKeyMask;
      } else {
        lunaboy.actionKey &= ~actionKeyMask;
      }
    }
  }

  if (event.data.type === 'loadROM') {
    try {
      lunaboy.loadUploadedRom(event.data.data);
    } catch (error) {
      postMessage({ type: 'error', message: error.message });
    }
  }

  if (event.data.type === 'loadPreInstalledRom') {
    try {
      await lunaboy.loadPreInstalledRom(event.data.romName);
    } catch (error) {
      postMessage({ type: 'error', message: error.message });
    }
  }
});
