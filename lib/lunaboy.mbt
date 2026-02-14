///|
const CPU_CLOCK_HZ : UInt64 = 4_194_304

///|
const M_CYCLE_CLOCK : UInt64 = 4

///|
const M_CYCLE_NANOS : U16 = 953 // M_CYCLE_CLOCK * 1_000_000_000 / CPU_CLOCK_HZ

///|
priv struct Emulator {
  cpu : Cpu
  bus : Bus
}

///|
priv struct GlobalState {
  mut emulator : Emulator?
}

///|
let gs : GlobalState = { emulator: None }

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
  let cartridge = Cartridge::new(rom)
  let bus = Bus::new(bootrom, cartridge)
  let cpu = Cpu::new()

  Emulator::{ cpu, bus }
}

///|
fn get_emulator() -> Emulator {
  gs.emulator.unwrap()
}

///|
pub fn init_emulator(bootrom : FixedArray[U8], rom : FixedArray[U8]) -> Unit {
  gs.emulator = Some(Emulator::new(Bootrom::new(bootrom), rom))
}

///|
pub fn step_until_frame() -> Unit {
  let emulator = get_emulator()

  while true {
    emulator.cpu.emulate_cycle(emulator.bus)
    emulator.bus.timer.emulate_cycle(emulator.cpu.interrupts)
    if emulator.bus.ppu.oam_dma is Some(addr) {
      emulator.bus.ppu.oam_dma_emulate_cycle(
        emulator.bus.read(emulator.cpu.interrupts, addr),
      )
    }
    if emulator.bus.ppu.emulate_cycle(emulator.cpu.interrupts) {
      break
    }
  }
}

///|
pub fn lcd_buffer() -> FixedArray[UInt] {
  get_emulator().bus.ppu.buffer
}

///|
pub fn set_input(direction_pressed : U8, action_pressed : U8) -> Unit {
  let emulator = get_emulator()

  emulator.bus.joypad.direction_button(
    0xFF - direction_pressed,
    emulator.cpu.interrupts,
  )
  emulator.bus.joypad.action_button(
    0xFF - action_pressed,
    emulator.cpu.interrupts,
  )
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

    }
  }
}
