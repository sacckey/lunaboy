///|
pub type U8 = Byte

///|
pub type U16 = UInt16

///|
fn U8::to_i8(self : U8) -> Int16 {
  (Int16::from_byte(self) ^ 0x80) - 0x80
}

///|
fn U8::to_u16(self : U8) -> U16 {
  self.to_uint16()
}

///|
fn U8::trailing_zeros(self : U8) -> Int {
  if self == 0 {
    return 8
  }

  let mut n = 0
  let mut v = self
  while (v & 1) == 0 {
    n += 1
    v = v >> 1
  }
  n
}

///|
fn U16::to_u8(self : U16) -> U8 {
  self.to_byte()
}

///|
fn Bool::to_u8(self : Bool) -> U8 {
  self.to_uint().to_byte()
}

///|
fn Int::to_u8(self : Int) -> U8 {
  self.to_byte()
}
