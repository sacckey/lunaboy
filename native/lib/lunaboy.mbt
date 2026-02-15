///|
fn load_rom(path : String) -> FixedArray[Byte] raise {
  @fs.read_file_to_bytes(path).to_fixedarray()
}

///|
pub fn run_emulator(rom_path : String?) -> Unit raise {
  let resolved_rom_path = rom_path.unwrap_or("lib/roms/hello-world.gb")
  let rom = load_rom(resolved_rom_path)

  @core.init_emulator(rom)
  let platform = Platform::new()

  while true {
    @core.step_until_frame()
    platform.draw_lcd(@core.lcd_buffer())
    if platform.poll_quit() {
      break
    }

    platform.update_input()
    @core.set_input(platform.direction_pressed(), platform.action_pressed())
  }

  platform.clear()
}
