///|
priv struct WRam(FixedArray[U8])

///|
fn WRam::new() -> Self {
  FixedArray::make(0x2000, 0)
}

///|
fn WRam::read(self : Self, addr : U16) -> U8 {
  self.0[addr.to_int() & 0x1FFF]
}

///|
fn WRam::write(self : Self, addr : U16, val : U8) -> Unit {
  self.0[addr.to_int() & 0x1FFF] = val
}
