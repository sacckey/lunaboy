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
fn Emulator::step_m_cycle(self : Self) -> Bool {
  self.cpu.emulate_cycle(self.bus)
  self.bus.timer.emulate_cycle(self.cpu.interrupts)
  if self.bus.ppu.oam_dma is Some(addr) {
    self.bus.ppu.oam_dma_emulate_cycle(self.bus.read(self.cpu.interrupts, addr))
  }
  self.bus.ppu.emulate_cycle(self.cpu.interrupts)
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
    if emulator.step_m_cycle() {
      break
    }
  }
}

///|
pub fn run_cycles(cycles : Int) -> Int {
  if cycles <= 0 {
    return 0
  }

  let emulator = get_emulator()
  let mut frame_count = 0
  for _i in 0..<cycles {
    if emulator.step_m_cycle() {
      frame_count += 1
    }
  }
  frame_count
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
