///|
extern "wasm" fn load8_u(offset : Int) -> Int =
  #|(func (param i32) (result i32) (i32.load8_u (local.get 0)))

///|
extern "wasm" fn store32(offset : Int, value : Int) =
  #|(func (param i32 i32) (i32.store (local.get 0) (local.get 1)))

///|
extern "wasm" fn storef32(offset : Int, value : Float) =
  #|(func (param i32 f32) (f32.store (local.get 0) (local.get 1)))

///|
const FRAME_WIDTH : Int = 160

///|
const FRAME_HEIGHT : Int = 144

///|
const FRAMEBUFFER_BYTES : Int = FRAME_WIDTH * FRAME_HEIGHT * 4

///|
const AUDIO_BUFFER_OFFSET : Int = FRAMEBUFFER_BYTES

///|
fn load_bytes_from_memory(offset : Int, length : Int) -> FixedArray[U8] {
  FixedArray::makei(length, fn(i) { load8_u(offset + i).to_u8() })
}

///|
fn copy_lcd_buffer_to_memory() -> Unit {
  let pixels = lcd_buffer()
  for i = 0; i < pixels.length(); i = i + 1 {
    store32(i << 2, pixels[i].reinterpret_as_int())
  }
}

///|
fn copy_audio_samples_to_memory(samples : FixedArray[Float]) -> Int {
  for i = 0; i < samples.length(); i = i + 1 {
    storef32(AUDIO_BUFFER_OFFSET + (i << 2), samples[i])
  }
  samples.length()
}

///|
pub fn init_extern(rom_length : Int) -> Unit {
  let rom = load_bytes_from_memory(0, rom_length)
  init_emulator(rom)
}

///|
pub fn run_frame_extern() -> Unit {
  step_until_frame()
  copy_lcd_buffer_to_memory()
}

///|
pub fn run_cycles_extern(cycles : Int) -> Int {
  let frames = run_cycles(cycles)
  if frames > 0 {
    copy_lcd_buffer_to_memory()
  }
  frames
}

///|
pub fn set_input_extern(direction_pressed : Int, action_pressed : Int) -> Unit {
  set_input(direction_pressed.to_u8(), action_pressed.to_u8())
}

///|
pub fn pop_audio_extern() -> Int {
  match pop_audio_samples() {
    Some(samples) => copy_audio_samples_to_memory(samples)
    None => 0
  }
}
