///|
priv struct Bootrom {
  rom : FixedArray[U8]
  mut active : Bool
}

///|
fn Bootrom::new(rom : FixedArray[U8]) -> Self {
  { rom, active: true }
}

///|
fn Bootrom::is_active(self : Self) -> Bool {
  self.active
}

///|
fn Bootrom::read(self : Self, addr : U16) -> U8 {
  self.rom[addr.to_int()]
}

///|
fn Bootrom::write(self : Self, _addr : U16, val : U8) -> Unit {
  self.active = self.active && val == 0
}
