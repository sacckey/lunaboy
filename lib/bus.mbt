///|
priv struct Bus {
  bootrom : Bootrom
  cartridge : Cartridge
  wram : WRam
  hram : HRam
  ppu : Ppu
}

///|
fn Bus::new(bootrom : Bootrom, cartridge : Cartridge) -> Self {
  { bootrom, cartridge, wram: WRam::new(), hram: HRam::new(), ppu: Ppu::new() }
}

///|
fn Bus::read(self : Self, interrupts : Interrupts, addr : U16) -> U8 {
  match addr {
    0x0000..=0x00FF =>
      if self.bootrom.is_active() {
        self.bootrom.read(addr)
      } else {
        self.cartridge.read(addr)
      }
    0x0100..=0x7FFF => self.cartridge.read(addr)
    0x8000..=0x9FFF => self.ppu.read(addr)
    0xA000..=0xBFFF => self.cartridge.read(addr)
    0xC000..=0xFDFF => self.wram.read(addr)
    0xFE00..=0xFE9F => self.ppu.read(addr)
    0xFF0F => interrupts.read(addr)
    0xFF40..=0xFF4B => self.ppu.read(addr)
    0xFF80..=0xFFFE => self.hram.read(addr)
    0xFFFF => interrupts.read(addr)
    _ => 0xFF
  }
}

///|
fn Bus::write(
  self : Self,
  interrupts : Interrupts,
  addr : U16,
  val : U8,
) -> Unit {
  match addr {
    0x0000..=0x00FF =>
      if !self.bootrom.is_active() {
        self.cartridge.write(addr, val)
      }
    0x0100..=0x7FFF => self.cartridge.write(addr, val)
    0x8000..=0x9FFF => self.ppu.write(addr, val)
    0xA000..=0xBFFF => self.cartridge.write(addr, val)
    0xC000..=0xFDFF => self.wram.write(addr, val)
    0xFE00..=0xFE9F => self.ppu.write(addr, val)
    0xFF0F => interrupts.write(addr, val)
    0xFF40..=0xFF4B => self.ppu.write(addr, val)
    0xFF50 => self.bootrom.write(addr, val)
    0xFF80..=0xFFFE => self.hram.write(addr, val)
    0xFFFF => interrupts.write(addr, val)
    _ => ()
  }
}
