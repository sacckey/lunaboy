///|
const VBLANK : U8 = 0b00001

///|
const STAT : U8 = 0b00010

///|
const TIMER : U8 = 0b00100

///|
const SERIAL : U8 = 0b01000

///|
const JOYPAD : U8 = 0b10000

///|
priv struct Interrupts {
  mut ime : Bool
  mut int_flags : U8
  mut int_enable : U8
}

///|
impl Default for Interrupts with default() -> Interrupts {
  { ime: false, int_flags: 0x01, int_enable: 0x00 }
}

///|
fn Interrupts::irq(self : Self, val : U8) -> Unit {
  self.int_flags = self.int_flags | val
}

///|
fn Interrupts::read(self : Self, addr : U16) -> U8 {
  match addr {
    0xFF0F => self.int_flags
    0xFFFF => self.int_enable
    _ => panic()
  }
}

///|
fn Interrupts::write(self : Self, addr : U16, val : U8) -> Unit {
  match addr {
    0xFF0F => self.int_flags = val
    0xFFFF => self.int_enable = val
    _ => panic()
  }
}

///|
fn Interrupts::get_interrupt(self : Self) -> U8 {
  self.int_flags & self.int_enable & 0b11111
}
