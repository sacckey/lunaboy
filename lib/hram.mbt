///|
priv struct HRam(FixedArray[U8])

///|
fn HRam::new() -> Self {
  FixedArray::make(0x80, 0)
}

///|
fn HRam::read(self : Self, addr : U16) -> U8 {
  self.0[addr.to_int() & 0x7F]
}

///|
fn HRam::write(self : Self, addr : U16, val : U8) -> Unit {
  self.0[addr.to_int() & 0x7F] = val
}
