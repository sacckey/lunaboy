///|
const SAMPLE_RATE : Int = 48_000

///|
const CHANNELS : Int = 2

///|
const MAX_QUEUED_BYTES : Int = 8192

///|
extern "C" fn audio_open(sample_rate : Int, channels : Int) -> Bool = "lunaboy_audio_open"

///|
extern "C" fn audio_queue(ptr : @sdl.VoidPtr, len_bytes : Int) -> Bool = "lunaboy_audio_queue"

///|
extern "C" fn audio_queued_bytes() -> Int = "lunaboy_audio_queued_bytes"

///|
extern "C" fn audio_close() -> Unit = "lunaboy_audio_close"

///|
priv enum Audio {
  Audio
}

///|
fn log_audio_error(context : String) -> Unit {
  println("\{context}: \{@sdl.sdl_GetError()}")
}

///|
fn Audio::new() -> Self {
  if !audio_open(SAMPLE_RATE, CHANNELS) {
    log_audio_error("failed to open audio")
    panic()
  }
  Audio
}

///|
fn Audio::queue(_self : Self, samples : FixedArray[Float]) -> Unit {
  while audio_queued_bytes() > MAX_QUEUED_BYTES {
    @sdl.sdl_Delay(1)
  }
  if !audio_queue(as_void_ptr(samples), samples.length() * 4) {
    log_audio_error("failed to queue audio data")
    panic()
  }
}

///|
fn Audio::clear(_self : Self) -> Unit {
  audio_close()
}
