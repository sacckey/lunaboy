///|
priv struct Bus {
  bootrom : Bootrom
  wram : WRam
  hram : HRam
  ppu : Ppu
}

///|
fn Bus::new(bootrom : Bootrom) -> Self {
  { bootrom, wram: WRam::new(), hram: HRam::new(), ppu: Ppu::new() }
}

///|
fn Bus::read(self : Self, addr : U16) -> U8 {
  match addr {
    0x0000..=0x00FF =>
      if self.bootrom.is_active() {
        self.bootrom.read(addr)
      } else {
        0xFF
      }
    0x8000..=0x9FFF => self.ppu.read(addr)
    0xC000..=0xFDFF => self.wram.read(addr)
    0xFE00..=0xFE9F => self.ppu.read(addr)
    0xFF40..=0xFF4B => self.ppu.read(addr)
    0xFF80..=0xFFFE => self.hram.read(addr)
    _ => 0xFF
  }
}

///|
fn Bus::write(self : Self, addr : U16, val : U8) -> Unit {
  match addr {
    0x8000..=0x9FFF => self.ppu.write(addr, val)
    0xC000..=0xFDFF => self.wram.write(addr, val)
    0xFE00..=0xFE9F => self.ppu.write(addr, val)
    0xFF40..=0xFF4B => self.ppu.write(addr, val)
    0xFF50 => self.bootrom.write(addr, val)
    0xFF80..=0xFFFE => self.hram.write(addr, val)
    _ => ()
  }
}
