///|
priv struct Mbc1 {
  mut sram_enable : Bool
  mut low_bank : Int
  mut high_bank : Int
  mut bank_mode : Bool
  rom_banks : Int
}

///|
priv enum Mbc {
  NoMbc
  Mbc1(Mbc1)
}

///|
fn Mbc::new(cartridge_type : U8, rom_banks : Int) -> Self {
  match cartridge_type {
    0x00 | 0x08 | 0x09 => Mbc::NoMbc
    0x01..=0x03 =>
      Mbc::Mbc1(Mbc1::{
        sram_enable: false,
        low_bank: 0b00001,
        high_bank: 0b00,
        bank_mode: false,
        rom_banks,
      })
    _ => panic()
  }
}

///|
fn Mbc::write(self : Self, addr : U16, val : U8) -> Unit {
  match self {
    Mbc::NoMbc => ()
    Mbc::Mbc1(mbc) =>
      match addr {
        0x0000..=0x1FFF => mbc.sram_enable = (val & 0x0F) == 0x0A
        0x2000..=0x3FFF => {
          let low = val & 0b11111
          mbc.low_bank = if low == 0 { 0b00001 } else { low.to_int() }
        }
        0x4000..=0x5FFF => mbc.high_bank = (val & 0b11).to_int()
        0x6000..=0x7FFF => mbc.bank_mode = (val & 0b1) > 0
        _ => panic()
      }
  }
}

///|
fn Mbc::type_name(self : Self) -> String {
  match self {
    Mbc::NoMbc => "NO MBC"
    Mbc::Mbc1(_) => "MBC1"
  }
}

///|
fn Mbc::get_addr(self : Self, addr : U16) -> Int {
  match self {
    Mbc::NoMbc => addr.to_int()
    Mbc::Mbc1(mbc) =>
      match addr {
        0x0000..=0x3FFF =>
          if mbc.bank_mode {
            (mbc.high_bank << 19) | (addr & 0x3FFF).to_int()
          } else {
            (addr & 0x3FFF).to_int()
          }
        0x4000..=0x7FFF =>
          (mbc.high_bank << 19) |
          ((mbc.low_bank & (mbc.rom_banks - 1)) << 14) |
          (addr & 0x3FFF).to_int()
        0xA000..=0xBFFF =>
          if mbc.bank_mode {
            (mbc.high_bank << 13) | (addr & 0x1FFF).to_int()
          } else {
            (addr & 0x1FFF).to_int()
          }
        _ => panic()
      }
  }
}
