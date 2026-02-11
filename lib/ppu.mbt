///|
const LCD_WIDTH = 160

///|
const LCD_HEIGHT = 144

///|
const PPU_ENABLE : U8 = 0b10000000

///|
const WINDOW_TILE_MAP : U8 = 0b01000000

///|
const WINDOW_ENABLE : U8 = 0b00100000

///|
const TILE_DATA_ADDRESSING_MODE : U8 = 0b00010000

///|
const BG_TILE_MAP : U8 = 0b00001000

///|
const SPRITE_SIZE : U8 = 0b00000100

///|
const SPRITE_ENABLE : U8 = 0b00000010

///|
const BG_WINDOW_ENABLE : U8 = 0b00000001

///|
const LYC_EQ_LY_INT : U8 = 0b01000000

///|
const OAM_SCAN_INT : U8 = 0b00100000

///|
const VBLANK_INT : U8 = 0b00010000

///|
const HBLANK_INT : U8 = 0b00001000

///|
const LYC_EQ_LY : U8 = 0b00000100

///|
enum Mode {
  HBlank = 0
  VBlank = 1
  OamScan = 2
  Drawing = 3
} derive(Eq)

///|
fn Mode::to_u8(self : Self) -> U8 {
  match self {
    Mode::HBlank => 0
    Mode::VBlank => 1
    Mode::OamScan => 2
    Mode::Drawing => 3
  }
}

///|
priv struct Ppu {
  mut cycles : U8
  mut mode : Mode
  mut lcdc : U8
  mut stat : U8
  mut scy : U8
  mut scx : U8
  mut ly : U8
  mut lyc : U8
  mut bgp : U8
  mut obp0 : U8
  mut obp1 : U8
  mut wy : U8
  mut wx : U8
  mut wly : U8
  vram : FixedArray[U8]
  oam : FixedArray[U8]
  buffer : FixedArray[UInt]
}

///|
fn Ppu::new() -> Ppu {
  Ppu::{
    cycles: 20,
    mode: Mode::OamScan,
    lcdc: 0,
    stat: 0,
    scy: 0,
    scx: 0,
    ly: 0,
    lyc: 0,
    bgp: 0,
    obp0: 0,
    obp1: 0,
    wy: 0,
    wx: 0,
    wly: 0,
    vram: FixedArray::make(0x2000, 0),
    oam: FixedArray::make(0xA0, 0),
    buffer: FixedArray::make(LCD_WIDTH * LCD_HEIGHT, 0xffffffff),
  }
}

///|
fn Ppu::read(self : Self, addr : U16) -> U8 {
  match addr {
    0x8000..=0x9FFF =>
      if self.mode == Mode::Drawing {
        0xFF
      } else {
        self.vram[addr.to_int() & 0x1FFF]
      }
    0xFE00..=0xFE9F =>
      if self.mode == Mode::Drawing || self.mode == Mode::OamScan {
        0xFF
      } else {
        self.oam[addr.to_int() & 0x00FF]
      }
    0xFF40 => self.lcdc
    0xFF41 => 0x80 | self.stat | self.mode.to_u8()
    0xFF42 => self.scy
    0xFF43 => self.scx
    0xFF44 => self.ly
    0xFF45 => self.lyc
    0xFF47 => self.bgp
    0xFF48 => self.obp0
    0xFF49 => self.obp1
    0xFF4A => self.wy
    0xFF4B => self.wx
    _ => panic()
  }
}

///|
fn Ppu::write(self : Self, addr : U16, val : U8) -> Unit {
  match addr {
    0x8000..=0x9FFF =>
      if self.mode != Mode::Drawing {
        self.vram[addr.to_int() & 0x1FFF] = val
      }
    0xFE00..=0xFE9F =>
      if self.mode != Mode::Drawing && self.mode != Mode::OamScan {
        self.oam[addr.to_int() & 0xFF] = val
      }
    0xFF40 => self.lcdc = val
    0xFF41 => self.stat = (self.stat & LYC_EQ_LY) | (val & 0xF8)
    0xFF42 => self.scy = val
    0xFF43 => self.scx = val
    0xFF44 => ()
    0xFF45 => self.lyc = val
    0xFF47 => self.bgp = val
    0xFF48 => self.obp0 = val
    0xFF49 => self.obp1 = val
    0xFF4A => self.wy = val
    0xFF4B => self.wx = val
    _ => panic()
  }
}

///|
fn Ppu::get_pixel_from_tile(
  self : Self,
  tile_idx : Int,
  row : Int,
  col : Int,
) -> U8 {
  let r = row * 2
  let c = 7 - col
  let tile_addr = tile_idx << 4
  let low = self.vram[(tile_addr | r) & 0x1FFF]
  let high = self.vram[(tile_addr | (r + 1)) & 0x1FFF]
  (((high >> c) & 1) << 1) | ((low >> c) & 1)
}

///|
fn Ppu::get_tile_idx_from_tile_map(
  self : Self,
  tile_map : Bool,
  row : Int,
  col : Int,
) -> Int {
  let start_addr = 0x1800 | (tile_map.to_int() << 10)
  let ret = self.vram[start_addr | (((row << 5) + col) & 0x3FF)]
  if (self.lcdc & TILE_DATA_ADDRESSING_MODE) > 0 {
    ret.to_int()
  } else {
    ret.to_i8().to_int() + 0x100
  }
}

///|
fn Ppu::render_bg(self : Self) -> Unit {
  if (self.lcdc & BG_WINDOW_ENABLE) == 0 {
    return
  }
  let y = (self.ly + self.scy).to_int()

  for i in 0..<LCD_WIDTH {
    let x = (i.to_u8() + self.scx).to_int()

    let tile_idx = self.get_tile_idx_from_tile_map(
      (self.lcdc & BG_TILE_MAP) > 0,
      y >> 3,
      x >> 3,
    )

    let pixel = self.get_pixel_from_tile(tile_idx, y & 7, x & 7).to_int()
    self.buffer[LCD_WIDTH * self.ly.to_int() + i] = match
      (self.bgp >> (pixel << 1)) & 0b11 {
      0b00 => 0xFFFFFFFF
      0b01 => 0xFFAAAAAA
      0b10 => 0xFF555555
      _ => 0xFF000000
    }
  }
}

///|
fn Ppu::render_window(self : Self, bg_prio : FixedArray[Bool]) -> Unit {
  if (self.lcdc & BG_WINDOW_ENABLE) == 0 ||
    (self.lcdc & WINDOW_ENABLE) == 0 ||
    self.wy > self.ly {
    return
  }

  let mut wly_add = (0 : U8)
  let y = self.wly.to_int()
  for i in 0..<LCD_WIDTH {
    let x = i - (self.wx.to_int() - 7)
    if x < 0 {
      continue
    }

    wly_add = 1

    let tile_idx = self.get_tile_idx_from_tile_map(
      (self.lcdc & WINDOW_TILE_MAP) > 0,
      y >> 3,
      x >> 3,
    )

    let pixel = self.get_pixel_from_tile(tile_idx, y & 7, x & 7).to_int()
    self.buffer[LCD_WIDTH * self.ly.to_int() + i] = match
      (self.bgp >> (pixel << 1)) & 0b11 {
      0b00 => 0xFFFFFFFF
      0b01 => 0xFFAAAAAA
      0b10 => 0xFF555555
      _ => 0xFF000000
    }
    bg_prio[i] = pixel != 0
  }
  self.wly += wly_add
}

///|
fn Ppu::check_lyc_eq_ly(self : Self) -> Unit {
  if self.ly == self.lyc {
    self.stat = self.stat | LYC_EQ_LY
  } else {
    self.stat = self.stat & LYC_EQ_LY.lnot()
  }
}

///|
fn Ppu::emulate_cycle(self : Self) -> Bool {
  if (self.lcdc & PPU_ENABLE) == 0 {
    return false
  }

  self.cycles -= 1
  if self.cycles > 0 {
    return false
  }

  let mut ret = false
  match self.mode {
    Mode::HBlank => {
      self.ly += 1
      if self.ly < 144 {
        self.mode = Mode::OamScan
        self.cycles = 20
      } else {
        self.mode = Mode::VBlank
        self.cycles = 114
      }
      self.check_lyc_eq_ly()
    }
    Mode::VBlank => {
      self.ly += 1
      if self.ly > 153 {
        ret = true
        self.ly = 0
        self.wly = 0
        self.mode = Mode::OamScan
        self.cycles = 20
      } else {
        self.cycles = 114
      }
      self.check_lyc_eq_ly()
    }
    Mode::OamScan => {
      self.mode = Mode::Drawing
      self.cycles = 43
    }
    Mode::Drawing => {
      self.render_bg()
      self.mode = Mode::HBlank
      self.cycles = 51
    }
  }

  ret
}
