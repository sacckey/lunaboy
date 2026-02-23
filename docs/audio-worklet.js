const BUFFERED_FRAMES = 16_384;
const BUFFER_MASK = BUFFERED_FRAMES - 1;

const samplesLeft = new Float32Array(BUFFERED_FRAMES);
const samplesRight = new Float32Array(BUFFERED_FRAMES);

let writeCursor = 0;
let readCursor = 0;

function availableFrames() {
  return (writeCursor - readCursor) & BUFFER_MASK;
}

function pushSamples(interleavedSamples) {
  const frameCount = interleavedSamples.length >> 1;
  for (let i = 0; i < frameCount; i += 1) {
    if (availableFrames() >= BUFFERED_FRAMES - 1) {
      readCursor = (readCursor + 1) & BUFFER_MASK;
    }

    const srcIndex = i << 1;
    samplesLeft[writeCursor] = interleavedSamples[srcIndex];
    samplesRight[writeCursor] = interleavedSamples[srcIndex + 1];
    writeCursor = (writeCursor + 1) & BUFFER_MASK;
  }
}

class LunaboyAudioProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.port.onmessage = (event) => {
      pushSamples(new Float32Array(event.data));
    };
  }

  process(_inputs, outputs) {
    const outputLeft = outputs[0][0];
    const outputRight = outputs[0][1];

    for (let i = 0; i < outputLeft.length; i += 1) {
      if (availableFrames() > 0) {
        outputLeft[i] = samplesLeft[readCursor];
        outputRight[i] = samplesRight[readCursor];
        readCursor = (readCursor + 1) & BUFFER_MASK;
      } else {
        outputLeft[i] = 0;
        outputRight[i] = 0;
      }
    }

    return true;
  }
}

registerProcessor('lunaboy-audio-processor', LunaboyAudioProcessor);
