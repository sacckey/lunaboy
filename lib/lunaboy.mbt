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
  lcd : Lcd
}

///|
pub fn run_emulator() -> Unit raise {
  let rom = @fs.read_file_to_bytes("lib/dmg_bootrom.bin")
  let bootrom = Bootrom::new(rom.to_fixedarray())
  let emulator = Emulator::new(bootrom)

  emulator.run()
}

///|
fn Emulator::new(bootrom : Bootrom) -> Self {
  let lcd = Lcd::new()
  let bus = Bus::new(bootrom)
  let cpu = Cpu::new()

  Emulator::{ cpu, bus, lcd }
}

///|
fn Emulator::run(self : Self) -> Unit {
  while true {
    self.cpu.emulate_cycle(self.bus)
    if self.bus.ppu.emulate_cycle() {
      self.lcd.draw(self.bus.ppu.buffer)
    }
  }
}
