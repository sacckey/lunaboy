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
    this.pendingBuffers = [];
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
      this.context = new window.AudioContext({ sampleRate: 48_000 });
      await this.context.audioWorklet.addModule('./audio-worklet.js');
      this.processor = new AudioWorkletNode(
        this.context,
        'lunaboy-audio-processor',
        { outputChannelCount: [2] },
      );
      this.processor.connect(this.context.destination);

      while (this.pendingBuffers.length > 0) {
        const buffer = this.pendingBuffers.shift();
        this.processor.port.postMessage(buffer, [buffer]);
      }

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
      this.pendingBuffers.length = 0;
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
    if (this.muted) {
      return;
    }
    if (this.processor) {
      this.processor.port.postMessage(buffer, [buffer]);
      return;
    }
    this.pendingBuffers.push(buffer);
    if (this.pendingBuffers.length > 64) {
      this.pendingBuffers.shift();
    }
  }
}

const audioPlayer = new AudioPlayer();

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

document.addEventListener('keydown', (event) => {
  worker.postMessage({ type: 'keydown', code: event.code });
});
document.addEventListener('keyup', (event) => {
  worker.postMessage({ type: 'keyup', code: event.code });
});

const handleButtonPress = (event) => {
  event.preventDefault();
  worker.postMessage({ type: 'keydown', code: event.target.dataset.code });
}
const handleButtonRelease = (event) => {
  event.preventDefault();
  worker.postMessage({ type: 'keyup', code: event.target.dataset.code });
}
const buttons = document.querySelectorAll('.d-pad-button, .action-button, .start-select-button');
buttons.forEach(button => {
  button.addEventListener('mousedown', handleButtonPress);
  button.addEventListener('mouseup', handleButtonRelease);
  button.addEventListener('touchstart', handleButtonPress);
  button.addEventListener('touchend', handleButtonRelease);
});

const romInput = document.getElementById('rom-input');
romInput.addEventListener('change', (event) => {
  const file = event.target.files[0];
  if (file) {
    const reader = new FileReader();

    reader.onload = (e) => {
      const romData = e.target.result;
      worker.postMessage({ type: 'loadROM', data: romData }, [romData]);
    };

    reader.readAsArrayBuffer(file);
  }
});

const romSelectBox = document.getElementById('rom-select-box');
romSelectBox.addEventListener('change', (event) => {
  worker.postMessage({ type: 'loadPreInstalledRom', romName: event.target.value });
});

const throttleToggle = document.getElementById('throttle-toggle');
throttleToggle.addEventListener('change', (event) => {
  worker.postMessage({ type: 'setThrottle', enabled: event.target.checked });
});

const muteToggle = document.getElementById('mute-toggle');
muteToggle.addEventListener('change', (event) => {
  audioPlayer.setMuted(event.target.checked);
});
audioPlayer.setMuted(muteToggle.checked);

const times = [];
const fpsDisplay = document.getElementById('fps-display');
worker.onmessage = (event) => {
  if (event.data.type === 'audioData') {
    audioPlayer.enqueue(event.data.data);
  }

  if (event.data.type === 'pixelData') {
    const pixelData = new Uint8ClampedArray(event.data.data);
    const imageData = new ImageData(pixelData, 160, 144);
    tmpCanvasContext.putImageData(imageData, 0, 0);
    canvasContext.drawImage(tmpCanvas, 0, 0);

    const now = performance.now();
    while (times.length > 0 && times[0] <= now - 1000) {
      times.shift();
    }
    times.push(now);
    fpsDisplay.innerText = times.length.toString();
  }

  if (event.data.type === 'initialized') {
    romSelectBox.disabled = false;
    romInput.disabled = false;
    document.getElementById('rom-upload-button').classList.remove('disabled');
    worker.postMessage({ type: 'setThrottle', enabled: throttleToggle.checked });
    worker.postMessage({ type: 'loadPreInstalledRom', romName: romSelectBox.value });
    worker.postMessage({ type: 'startLunaboy' });
  }

  if (event.data.type === 'error') {
    console.error('Error from Worker:', event.data.message);
  }
};

worker.postMessage({ type: 'initLunaboy' });
