///|
extern "wasm" fn load8_u(offset : Int) -> Int =
  #|(func (param i32) (result i32) (i32.load8_u (local.get 0)))

///|
extern "wasm" fn store32(offset : Int, value : Int) =
  #|(func (param i32 i32) (i32.store (local.get 0) (local.get 1)))

///|
fn load_bytes_from_memory(offset : Int, length : Int) -> FixedArray[U8] {
  FixedArray::makei(length, fn(i) { load8_u(offset + i).to_u8() })
}

///|
pub fn init_extern(rom_length : Int) -> Unit {
  let rom = load_bytes_from_memory(0, rom_length)
  init_emulator(rom)
}

///|
pub fn run_frame_extern() -> Unit {
  step_until_frame()
  let pixels = lcd_buffer()

  for i = 0; i < pixels.length(); i = i + 1 {
    store32(i << 2, pixels[i].reinterpret_as_int())
  }
}

///|
pub fn set_input_extern(direction_pressed : Int, action_pressed : Int) -> Unit {
  set_input(direction_pressed.to_u8(), action_pressed.to_u8())
}
