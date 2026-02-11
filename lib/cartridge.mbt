///|
priv struct CartridgeHeader {
  entry_point : FixedArray[U8]
  logo : FixedArray[U8]
  title : FixedArray[U8]
  maker : FixedArray[U8]
  cgb_flag : U8
  new_licensee : FixedArray[U8]
  sgb_flag : U8
  cartridge_type : U8
  rom_size : U8
  sram_size : U8
  destination : U8
  old_licensee : U8
  game_version : U8
  header_checksum : U8
  global_checksum : FixedArray[U8]
}

///|
fn CartridgeHeader::new(data : FixedArray[U8]) -> Self {
  if data.length() != 0x50 {
    panic()
  }

  let ret = CartridgeHeader::{
    entry_point: FixedArray::makei(4, fn(i) { data[i] }),
    logo: FixedArray::makei(48, fn(i) { data[0x04 + i] }),
    title: FixedArray::makei(11, fn(i) { data[0x34 + i] }),
    maker: FixedArray::makei(4, fn(i) { data[0x3F + i] }),
    cgb_flag: data[0x43],
    new_licensee: FixedArray::makei(2, fn(i) { data[0x44 + i] }),
    sgb_flag: data[0x46],
    cartridge_type: data[0x47],
    rom_size: data[0x48],
    sram_size: data[0x49],
    destination: data[0x4A],
    old_licensee: data[0x4B],
    game_version: data[0x4C],
    header_checksum: data[0x4D],
    global_checksum: FixedArray::makei(2, fn(i) { data[0x4E + i] }),
  }

  let mut chksum : U8 = 0
  for i in 0x34..<=0x4C {
    chksum = chksum - data[i] - 1
  }

  if chksum != ret.header_checksum {
    panic()
  }

  ret
}

///|
fn CartridgeHeader::rom_size(self : Self) -> Int {
  1 << (self.rom_size.to_int() + 15)
}

///|
fn CartridgeHeader::sram_size(self : Self) -> Int {
  match self.sram_size {
    0x00 => 0
    0x01 => 0x800
    0x02 => 0x2000
    0x03 => 0x8000
    0x04 => 0x20000
    0x05 => 0x100000
    _ => panic()
  }
}

///|
priv struct Cartridge {
  rom : FixedArray[U8]
  sram : FixedArray[U8]
  mbc : Mbc
}

///|
fn decode_title(title : FixedArray[U8]) -> String {
  let builder = StringBuilder::new()
  for i in 0..<title.length() {
    let b = title[i]
    if b == 0 {
      break
    }
    builder.write_char(b.to_char())
  }
  builder.to_string()
}

///|
fn Cartridge::new(rom : FixedArray[U8]) -> Self {
  if rom.length() < 0x150 {
    panic()
  }

  let header = CartridgeHeader::new(
    FixedArray::makei(0x50, fn(i) { rom[0x100 + i] }),
  )
  let title = decode_title(header.title)
  let rom_size = header.rom_size()
  let sram_size = header.sram_size()
  let rom_banks = rom_size >> 14
  let mbc = Mbc::new(header.cartridge_type, rom_banks)

  println(
    "cartridge info { title: \{title}, type: \{mbc.type_name()}, rom_size: \{rom_size} B, sram_size: \{sram_size} B }",
  )

  if rom.length() != rom_size {
    panic()
  }

  { rom, sram: FixedArray::make(sram_size, 0), mbc }
}

///|
fn Cartridge::read(self : Self, addr : U16) -> U8 {
  match addr {
    0x0000..=0x7FFF =>
      self.rom[self.mbc.get_addr(addr) & (self.rom.length() - 1)]
    0xA000..=0xBFFF =>
      match self.mbc {
        Mbc::NoMbc => self.sram[addr.to_int() & (self.sram.length() - 1)]
        Mbc::Mbc1(mbc) =>
          if mbc.sram_enable {
            self.sram[self.mbc.get_addr(addr) & (self.sram.length() - 1)]
          } else {
            0xFF
          }
      }
    _ => panic()
  }
}

///|
fn Cartridge::write(self : Self, addr : U16, val : U8) -> Unit {
  match addr {
    0x0000..=0x7FFF => self.mbc.write(addr, val)
    0xA000..=0xBFFF =>
      match self.mbc {
        Mbc::NoMbc => self.sram[addr.to_int() & (self.sram.length() - 1)] = val
        Mbc::Mbc1(mbc) =>
          if mbc.sram_enable {
            self.sram[self.mbc.get_addr(addr) & (self.sram.length() - 1)] = val
          }
      }
    _ => panic()
  }
}
