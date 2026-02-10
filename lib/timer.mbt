///|
struct Timer {
  mut div : U16
  mut tima : U8
  mut overflow : Bool
  mut tma : U8
  mut tac : U8
} derive(Default)

///|
fn Timer::emulate_cycle(self : Self, interrupts : Interrupts) -> Unit {
  self.div += 4

  let modulo : U16 = match self.tac & 0b11 {
    0b01 => 16
    0b10 => 64
    0b11 => 256
    _ => 1024
  }

  if self.overflow {
    self.tima = self.tma
    self.overflow = false
    interrupts.irq(TIMER)
  } else if (self.tac & 0b100) > 0 && (self.div & (modulo - 1)) == 0 {
    let tima = self.tima + 1
    self.tima = tima
    self.overflow = tima == 0
  }
}

///|
fn Timer::read(self : Self, addr : U16) -> U8 {
  match addr {
    0xFF04 => (self.div >> 8).to_u8()
    0xFF05 => self.tima
    0xFF06 => self.tma
    0xFF07 => 0b11111000 | self.tac
    _ => panic()
  }
}

///|
fn Timer::write(self : Self, addr : U16, val : U8) -> Unit {
  match addr {
    0xFF04 => self.div = 0
    0xFF05 => if !self.overflow { self.tima = val }
    0xFF06 => self.tma = val
    0xFF07 => self.tac = val & 0b111
    _ => panic()
  }
}
