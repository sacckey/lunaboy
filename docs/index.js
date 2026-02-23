const worker = new Worker('./worker.js', { type: 'module' });

const SCALE = 2;
const canvas = document.getElementById('canvas');
const canvasContext = canvas.getContext('2d');
canvasContext.scale(SCALE, SCALE);
const tmpCanvas = document.createElement('canvas');
const tmpCanvasContext = tmpCanvas.getContext('2d');
tmpCanvas.width = canvas.width;
tmpCanvas.height = canvas.height;
class AudioPlayer {
  constructor() {
    this.context = null;
    this.processor = null;
    this.startingPromise = null;
    this.muted = true;
  }

  isReady() {
    return this.context !== null && this.processor !== null;
  }

  async ensureStarted() {
    if (this.isReady()) {
      if (this.context.state === 'suspended') {
        await this.context.resume();
      }
      return;
    }
    if (this.startingPromise) {
      await this.startingPromise;
      return;
    }

    this.startingPromise = (async () => {
      this.context = new window.AudioContext({
        sampleRate: 48_000,
        latencyHint: 'interactive',
      });
      await this.context.audioWorklet.addModule('./audio-worklet.js');
      this.processor = new AudioWorkletNode(
        this.context,
        'lunaboy-audio-processor',
        { outputChannelCount: [2] },
      );
      this.processor.connect(this.context.destination);

      if (this.context.state === 'suspended') {
        await this.context.resume();
      }
    })();

    try {
      await this.startingPromise;
    } finally {
      this.startingPromise = null;
    }
  }

  setMuted(muted) {
    this.muted = muted;
    if (muted) {
      if (this.context && this.context.state === 'running') {
        this.context.suspend().catch(() => {});
      }
      return;
    }

    this.ensureStarted().catch((error) => {
      console.error('Audio initialization failed:', error);
    });
  }

  enqueue(buffer) {
    if (this.muted || !this.processor) {
      return;
    }
    this.processor.port.postMessage(buffer, [buffer]);
  }
}

const audioPlayer = new AudioPlayer();

function postToWorker(type, payload = {}, transferables = null) {
  const message = { type, ...payload };
  if (transferables) {
    worker.postMessage(message, transferables);
    return;
  }
  worker.postMessage(message);
}

// Display "LOADING..."
(() => {
  const str = `
    10000 01110 01110 11110 01110 10001 01110 00000 00000 00000
    10000 10001 10001 10001 00100 11001 10000 00000 00000 00000
    10000 10001 10001 10001 00100 10101 10011 00000 00000 00000
    10000 10001 11111 10001 00100 10011 10001 01100 01100 01100
    11111 01110 10001 11110 01110 10001 01110 01100 01100 01100
  `;
  const dotSize = 2;
  const rows = str.trim().split('\n')
  const xSpacing = canvas.width / (2 * SCALE) - rows[0].length * dotSize / 2;
  const ySpacing = canvas.height / (2 * SCALE) - rows.length * dotSize / 2;
  canvasContext.fillStyle = 'white';

  rows.forEach((row, y) => {
    [...row.trim()].forEach((char, x) => {
      if (char === '1') {
        canvasContext.fillRect(
          x * dotSize + xSpacing,
          y * dotSize + ySpacing,
          dotSize,
          dotSize
        );
      }
    });
  });
})();

function postInput(type, event) {
  event.preventDefault();
  postToWorker(type, { code: event.currentTarget.dataset.code });
}

for (const type of ['keydown', 'keyup']) {
  document.addEventListener(type, (event) => {
    postToWorker(type, { code: event.code });
  });
}

const buttons = document.querySelectorAll('.d-pad-button, .action-button, .start-select-button');
const buttonInputBindings = [
  ['mousedown', 'keydown'],
  ['mouseup', 'keyup'],
  ['touchstart', 'keydown'],
  ['touchend', 'keyup'],
];
buttons.forEach((button) => {
  buttonInputBindings.forEach(([domEventType, inputType]) => {
    button.addEventListener(domEventType, (event) => postInput(inputType, event));
  });
});

const romInput = document.getElementById('rom-input');
romInput.addEventListener('change', async (event) => {
  const file = event.target.files[0];
  if (!file) {
    return;
  }
  const romData = await file.arrayBuffer();
  postToWorker('loadROM', { data: romData }, [romData]);
});

const romSelectBox = document.getElementById('rom-select-box');
romSelectBox.addEventListener('change', (event) => {
  postToWorker('loadPreInstalledRom', { romName: event.target.value });
});

const throttleToggle = document.getElementById('throttle-toggle');
throttleToggle.addEventListener('change', (event) => {
  postToWorker('setThrottle', { enabled: event.target.checked });
});

const muteToggle = document.getElementById('mute-toggle');
muteToggle.addEventListener('change', (event) => {
  audioPlayer.setMuted(event.target.checked);
});
audioPlayer.setMuted(muteToggle.checked);

const times = [];
const fpsDisplay = document.getElementById('fps-display');
const romUploadButton = document.getElementById('rom-upload-button');

function updateFps() {
  const now = performance.now();
  while (times.length > 0 && times[0] <= now - 1000) {
    times.shift();
  }
  times.push(now);
  fpsDisplay.innerText = times.length.toString();
}

function handlePixelData(data) {
  const pixelData = new Uint8ClampedArray(data.data);
  const imageData = new ImageData(pixelData, 160, 144);
  tmpCanvasContext.putImageData(imageData, 0, 0);
  canvasContext.drawImage(tmpCanvas, 0, 0);
  updateFps();
}

const workerMessageHandlers = {
  audioData(data) {
    audioPlayer.enqueue(data.data);
  },
  pixelData(data) {
    handlePixelData(data);
  },
  initialized() {
    romSelectBox.disabled = false;
    romInput.disabled = false;
    romUploadButton.classList.remove('disabled');
    postToWorker('setThrottle', { enabled: throttleToggle.checked });
    postToWorker('loadPreInstalledRom', { romName: romSelectBox.value });
    postToWorker('startLunaboy');
  },
  error(data) {
    console.error('Error from Worker:', data.message);
  },
};

worker.onmessage = (event) => {
  const handler = workerMessageHandlers[event.data.type];
  if (handler) {
    handler(event.data);
  }
};

postToWorker('initLunaboy');
