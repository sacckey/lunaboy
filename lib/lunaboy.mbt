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
fn Emulator::new(rom : FixedArray[U8]) -> Self {
  let cartridge = Cartridge::new(rom)
  let bus = Bus::new(cartridge)
  let cpu = Cpu::new()
  cpu.fetch(bus)
  Emulator::{ cpu, bus }
}

///|
fn get_emulator() -> Emulator {
  gs.emulator.unwrap()
}

///|
pub fn init_emulator(rom : FixedArray[U8]) -> Unit {
  gs.emulator = Some(Emulator::new(rom))
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
