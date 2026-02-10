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
  let bootrom = Bootrom::new(@fs.read_file_to_bytes("lib/dmg_bootrom.bin").to_fixedarray())
  let rom = @fs.read_file_to_bytes("lib/roms/hello-world.gb").to_fixedarray()
  let emulator = Emulator::new(bootrom, rom)

  emulator.run()
}

///|
fn Emulator::new(bootrom : Bootrom, rom : FixedArray[U8]) -> Self {
  let lcd = Lcd::new()
  let cartridge = Cartridge::new(rom)
  let bus = Bus::new(bootrom, cartridge)
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
