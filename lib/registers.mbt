///|
struct Registers {
  mut pc : U16
  mut sp : U16
  mut a : U8
  mut b : U8
  mut c : U8
  mut d : U8
  mut e : U8
  mut f : U8
  mut h : U8
  mut l : U8
} derive(Debug, Default)

///|
fn Registers::af(self : Self) -> U16 {
  (self.a.to_u16() << 8) | self.f.to_u16()
}

///|
fn Registers::bc(self : Self) -> U16 {
  (self.b.to_u16() << 8) | self.c.to_u16()
}

///|
fn Registers::de(self : Self) -> U16 {
  (self.d.to_u16() << 8) | self.e.to_u16()
}

///|
fn Registers::hl(self : Self) -> U16 {
  (self.h.to_u16() << 8) | self.l.to_u16()
}

///|
fn Registers::write_af(self : Self, val : U16) -> Unit {
  self.a = (val >> 8).to_u8()
  self.f = (val & 0xF0).to_u8() // 下位4bitは常に0
}

///|
fn Registers::write_bc(self : Self, val : U16) -> Unit {
  self.b = (val >> 8).to_u8()
  self.c = val.to_u8()
}

///|
fn Registers::write_de(self : Self, val : U16) -> Unit {
  self.d = (val >> 8).to_u8()
  self.e = val.to_u8()
}

///|
fn Registers::write_hl(self : Self, val : U16) -> Unit {
  self.h = (val >> 8).to_u8()
  self.l = val.to_u8()
}

///|
fn Registers::zf(self : Self) -> Bool {
  (self.f & 0x80) > 0
}

///|
fn Registers::nf(self : Self) -> Bool {
  (self.f & 0x40) > 0
}

///|
fn Registers::hf(self : Self) -> Bool {
  (self.f & 0x20) > 0
}

///|
fn Registers::cf(self : Self) -> Bool {
  (self.f & 0x10) > 0
}

///|
fn Registers::set_zf(self : Self, zf : Bool) -> Unit {
  if zf {
    self.f = self.f | 0x80
  } else {
    self.f = self.f & 0x7F
  }
}

///|
fn Registers::set_nf(self : Self, nf : Bool) -> Unit {
  if nf {
    self.f = self.f | 0x40
  } else {
    self.f = self.f & 0xBF
  }
}

///|
fn Registers::set_hf(self : Self, hf : Bool) -> Unit {
  if hf {
    self.f = self.f | 0x20
  } else {
    self.f = self.f & 0xDF
  }
}

///|
fn Registers::set_cf(self : Self, cf : Bool) -> Unit {
  if cf {
    self.f = self.f | 0x10
  } else {
    self.f = self.f & 0xEF
  }
}
