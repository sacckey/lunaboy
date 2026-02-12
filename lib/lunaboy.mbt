///|
const CPU_CLOCK_HZ : UInt64 = 4_194_304

///|
const M_CYCLE_CLOCK : UInt64 = 4

///|
const M_CYCLE_NANOS : U16 = 953 // M_CYCLE_CLOCK * 1_000_000_000 / CPU_CLOCK_HZ

///|
priv struct Emulator {
  platform : Platform
  cpu : Cpu
  bus : Bus
}

///|
pub fn run_emulator(rom_path : String?) -> Unit raise {
  let bootrom = Bootrom::new(
    @fs.read_file_to_bytes("lib/dmg_bootrom.bin").to_fixedarray(),
  )

  let resolved_rom_path = rom_path.unwrap_or("lib/roms/hello-world.gb")
  let rom = @fs.read_file_to_bytes(resolved_rom_path).to_fixedarray()
  let emulator = Emulator::new(bootrom, rom)

  emulator.run()
}

///|
fn Emulator::new(bootrom : Bootrom, rom : FixedArray[U8]) -> Self {
  let platform = Platform::new()
  let cartridge = Cartridge::new(rom)
  let bus = Bus::new(bootrom, cartridge)
  let cpu = Cpu::new()

  Emulator::{ platform, cpu, bus }
}

///|
fn Emulator::run(self : Self) -> Unit {
  while true {
    self.cpu.emulate_cycle(self.bus)
    self.bus.timer.emulate_cycle(self.cpu.interrupts)
    if self.bus.ppu.oam_dma is Some(addr) {
      self.bus.ppu.oam_dma_emulate_cycle(
        self.bus.read(self.cpu.interrupts, addr),
      )
    }
    if self.bus.ppu.emulate_cycle(self.cpu.interrupts) {
      self.platform.draw_lcd(self.bus.ppu.buffer)
      if self.platform.poll_quit() {
        break
      }
      self.key_input_check()
    }
  }

  self.platform.clear()
}

///|
fn Emulator::key_input_check(self : Self) -> Unit {
  self.platform.update_input()

  self.bus.joypad.direction_button(
    0xFF - self.platform.direction_pressed(),
    self.cpu.interrupts,
  )
  self.bus.joypad.action_button(
    0xFF - self.platform.action_pressed(),
    self.cpu.interrupts,
  )
}
