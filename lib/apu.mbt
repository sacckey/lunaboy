///|
const SAMPLE_RATE : Int = 48_000

///|
const SAMPLES : Int = 1024

///|
const SAMPLE_PERIOD_T_CYCLES : Int = 4_194_304 / SAMPLE_RATE

///|
const FS_PERIOD_T_CYCLES : Int = 0x2000

const MASTER_GAIN : Float = 0.1

///|
let wave_duty : ReadOnlyArray[ReadOnlyArray[Float]] = [
  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0], // 12.5%
  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], // 25%
  [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], // 50%
  [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], // 75%
]

///|
fn bit(v : U8, i : Int) -> U8 {
  (v >> i) & 0b1
}

///|
priv struct Apu {
  mut enabled : Bool
  mut nr50 : U8
  mut nr51 : U8
  mut fs_cycles : Int
  mut sampling_cycles : Int
  mut fs : U8
  channel1 : Channel1
  channel2 : Channel2
  channel3 : Channel3
  channel4 : Channel4
  samples0 : FixedArray[Float]
  samples1 : FixedArray[Float]
  mut write_buffer : Int
  mut ready_buffer : Int
  mut sample_idx : Int
}

///|
fn Apu::new() -> Self {
  {
    enabled: false,
    nr50: 0,
    nr51: 0,
    fs_cycles: 0,
    sampling_cycles: 0,
    fs: 0,
    channel1: Channel1::default(),
    channel2: Channel2::default(),
    channel3: Channel3::default(),
    channel4: Channel4::default(),
    samples0: FixedArray::make(SAMPLES * 2, 0.0),
    samples1: FixedArray::make(SAMPLES * 2, 0.0),
    write_buffer: 0,
    ready_buffer: -1,
    sample_idx: 0,
  }
}

///|
fn Apu::write_sample(
  self : Self,
  sample_idx : Int,
  left : Float,
  right : Float,
) -> Unit {
  let offset = sample_idx * 2
  if self.write_buffer == 0 {
    self.samples0[offset] = left
    self.samples0[offset + 1] = right
  } else {
    self.samples1[offset] = left
    self.samples1[offset + 1] = right
  }
}

///|
fn Apu::swap_buffers(self : Self) -> Unit {
  self.ready_buffer = self.write_buffer
  self.write_buffer = self.write_buffer ^ 1
}

///|
fn Apu::take_samples(self : Self) -> FixedArray[Float]? {
  match self.ready_buffer {
    0 => {
      self.ready_buffer = -1
      Some(self.samples0)
    }
    1 => {
      self.ready_buffer = -1
      Some(self.samples1)
    }
    _ => None
  }
}

///|
fn Apu::emulate_cycle(self : Self) -> Unit {
  for _i in 0..<4 {
    self.fs_cycles += 1
    self.sampling_cycles += 1

    self.channel1.emulate_t_cycle()
    self.channel2.emulate_t_cycle()
    self.channel3.emulate_t_cycle()
    self.channel4.emulate_t_cycle()

    if self.fs_cycles >= FS_PERIOD_T_CYCLES {
      self.channel1.emulate_fs_cycle(self.fs)
      self.channel2.emulate_fs_cycle(self.fs)
      self.channel3.emulate_fs_cycle(self.fs)
      self.channel4.emulate_fs_cycle(self.fs)
      self.fs_cycles -= FS_PERIOD_T_CYCLES
      self.fs = (self.fs + 1) & 7
    }

    if self.sampling_cycles >= SAMPLE_PERIOD_T_CYCLES {
      self.sampling_cycles -= SAMPLE_PERIOD_T_CYCLES
      let left_sample = (
          Float::from_byte(bit(self.nr51, 7)) * self.channel4.dac_output() +
          Float::from_byte(bit(self.nr51, 6)) * self.channel3.dac_output() +
          Float::from_byte(bit(self.nr51, 5)) * self.channel2.dac_output() +
          Float::from_byte(bit(self.nr51, 4)) * self.channel1.dac_output()
        ) /
        4.0
      let right_sample = (
          Float::from_byte(bit(self.nr51, 3)) * self.channel4.dac_output() +
          Float::from_byte(bit(self.nr51, 2)) * self.channel3.dac_output() +
          Float::from_byte(bit(self.nr51, 1)) * self.channel2.dac_output() +
          Float::from_byte(bit(self.nr51, 0)) * self.channel1.dac_output()
        ) /
        4.0

      let left_volume = Float::from_byte((self.nr50 >> 4) & 0x7) / 7.0
      let right_volume = Float::from_byte(self.nr50 & 0x7) / 7.0

      self.write_sample(
        self.sample_idx,
        left_volume * left_sample * MASTER_GAIN,
        right_volume * right_sample * MASTER_GAIN,
      )
      self.sample_idx += 1
    }

    if self.sample_idx >= SAMPLES {
      self.sample_idx = 0
      self.swap_buffers()
    }
  }
}

///|
fn Apu::read(self : Self, addr : U16) -> U8 {
  match addr {
    0xFF24 => self.nr50
    0xFF25 => self.nr51
    0xFF26 =>
      self.channel1.enabled.to_u8() |
      (self.channel2.enabled.to_u8() << 1) |
      (self.channel3.enabled.to_u8() << 2) |
      (self.channel4.enabled.to_u8() << 3) |
      0x70 |
      (self.enabled.to_u8() << 7)
    0xFF10..=0xFF14 => self.channel1.read_nrxx(addr - 0xFF10)
    0xFF15..=0xFF19 => self.channel2.read_nrxx(addr - 0xFF15)
    0xFF1A..=0xFF1E => self.channel3.read_nrxx(addr - 0xFF1A)
    0xFF1F..=0xFF23 => self.channel4.read_nrxx(addr - 0xFF1F)
    0xFF30..=0xFF3F => self.channel3.read_wave_ram(addr - 0xFF30)
    _ => panic()
  }
}

///|
fn Apu::allow_write_when_disabled(addr : U16) -> Bool {
  match addr {
    0xFF11 | 0xFF16 | 0xFF1B | 0xFF20 | 0xFF26 => true
    0xFF30..=0xFF3F => true
    _ => false
  }
}

///|
fn Apu::length_only_mask(addr : U16) -> Bool {
  match addr {
    0xFF11 | 0xFF16 | 0xFF20 => true
    _ => false
  }
}

///|
fn Apu::write(self : Self, addr : U16, val : U8) -> Unit {
  if !self.enabled && !Apu::allow_write_when_disabled(addr) {
    return
  }

  let val = if !self.enabled && Apu::length_only_mask(addr) {
    val & 0b0011_1111
  } else {
    val
  }

  match addr {
    0xFF24 => self.nr50 = val
    0xFF25 => self.nr51 = val
    0xFF26 => {
      let enabled = (val & 0x80) > 0
      if !enabled && self.enabled {
        let mut a : U16 = 0xFF10
        while a <= 0xFF25 {
          self.write(a, 0x00)
          a += 1
        }
      } else if enabled && !self.enabled {
        self.fs_cycles = 0
        self.sampling_cycles = 0
        self.fs = 0
        self.channel1.wave_duty_position = 0
        self.channel2.wave_duty_position = 0
        self.channel3.wave_duty_position = 0
      }
      self.enabled = enabled
    }
    0xFF10..=0xFF14 => self.channel1.write_nrxx(addr - 0xFF10, val)
    0xFF15..=0xFF19 => self.channel2.write_nrxx(addr - 0xFF15, val)
    0xFF1A..=0xFF1E => self.channel3.write_nrxx(addr - 0xFF1A, val)
    0xFF1F..=0xFF23 => self.channel4.write_nrxx(addr - 0xFF1F, val)
    0xFF30..=0xFF3F => self.channel3.write_wave_ram(addr - 0xFF30, val)
    _ => panic()
  }
}

///|
priv struct Channel1 {
  mut length_timer : U8
  mut dac_enabled : Bool
  mut enabled : Bool
  mut frequency : U16
  mut length_enabled : Bool
  mut frequency_timer : U16
  mut wave_duty_position : Int
  mut wave_duty_pattern : U8
  mut period_timer : U8
  mut current_volume : U8
  mut shadow_frequency : U16
  mut is_decrementing : Bool
  mut sweep_period : U8
  mut sweep_shift : U8
  mut sweep_timer : U8
  mut sweep_enabled : Bool
  mut initial_volume : U8
  mut is_upwards : Bool
  mut period : U8
} derive(Default)

///|
fn Channel1::emulate_fs_cycle(self : Self, fs : U8) -> Unit {
  if (fs & 0b1) == 0 {
    self.length()
  }
  if fs == 7 {
    self.envelope()
  }
  if fs == 2 || fs == 6 {
    self.sweep()
  }
}

///|
fn Channel1::length(self : Self) -> Unit {
  if self.length_enabled && self.length_timer > 0 {
    self.length_timer -= 1
    self.enabled = self.enabled && self.length_timer > 0
  }
}

///|
fn Channel1::envelope(self : Self) -> Unit {
  if self.period != 0 {
    if self.period_timer > 0 {
      self.period_timer -= 1
    }

    if self.period_timer == 0 {
      self.period_timer = self.period

      if (self.current_volume < 0xF && self.is_upwards) ||
        (self.current_volume > 0x0 && !self.is_upwards) {
        if self.is_upwards {
          self.current_volume += 1
        } else {
          self.current_volume -= 1
        }
      }
    }
  }
}

///|
fn Channel1::sweep(self : Self) -> Unit {
  if self.sweep_timer > 0 {
    self.sweep_timer -= 1
  }

  if self.sweep_timer == 0 {
    self.sweep_timer = self.sweep_period

    if self.sweep_enabled {
      self.frequency = self.calculate_frequency()
      self.shadow_frequency = self.frequency
    }
  }
}

///|
fn Channel1::calculate_frequency(self : Self) -> U16 {
  if self.is_decrementing {
    let delta = self.shadow_frequency >> self.sweep_shift.to_int()
    if self.shadow_frequency >= delta {
      self.shadow_frequency - delta
    } else {
      0
    }
  } else {
    let v = self.shadow_frequency.to_int() +
      (self.shadow_frequency >> self.sweep_shift.to_int()).to_int()
    @cmp.minimum(2047, v).to_uint16()
  }
}

///|
fn Channel1::read_nrxx(self : Self, x : U16) -> U8 {
  match x {
    0 =>
      (self.sweep_period << 4) |
      (self.is_decrementing.to_u8() << 3) |
      self.sweep_shift |
      0x80
    1 => (self.wave_duty_pattern << 6) | 0b0011_1111
    2 =>
      (self.initial_volume << 4) | (self.is_upwards.to_u8() << 3) | self.period
    3 => 0xFF
    4 => (self.length_enabled.to_u8() << 6) | 0b1011_1111
    _ => panic()
  }
}

///|
fn Channel1::write_nrxx(self : Self, x : U16, val : U8) -> Unit {
  match x {
    0 => {
      self.sweep_period = (val >> 4) & 0x07
      self.is_decrementing = (val & 0x08) > 0
      self.sweep_shift = val & 0x07
    }
    1 => {
      self.wave_duty_pattern = (val >> 6) & 0b11
      self.length_timer = 64 - (val & 0x3F)
    }
    2 => {
      self.is_upwards = (val & 0x08) > 0
      self.initial_volume = val >> 4
      self.period = val & 0x07
      self.dac_enabled = (val & 0b1111_1000) > 0
      self.enabled = self.enabled && self.dac_enabled
    }
    3 => self.frequency = (self.frequency & 0x0700) | val.to_u16()
    4 => {
      self.frequency = (self.frequency & 0x00FF) | ((val & 0x07).to_u16() << 8)
      self.length_enabled = (val & 0x40) > 0
      if self.length_timer == 0 {
        self.length_timer = 64
      }
      let trigger = (val & 0x80) > 0
      if trigger && self.dac_enabled {
        self.enabled = true
        self.period_timer = self.period
        self.current_volume = self.initial_volume
        self.shadow_frequency = self.frequency
        self.sweep_timer = self.sweep_period
        self.sweep_enabled = self.sweep_period > 0 || self.sweep_shift > 0
      }
    }
    _ => panic()
  }
}

///|
fn Channel1::emulate_t_cycle(self : Self) -> Unit {
  if self.frequency_timer == 0 {
    self.frequency_timer = (2048 - self.frequency) * 4
    self.wave_duty_position = (self.wave_duty_position + 1) & 7
  }
  self.frequency_timer -= 1
}

///|
fn Channel1::dac_output(self : Self) -> Float {
  if self.dac_enabled && self.enabled {
    let dac_input = wave_duty[self.wave_duty_pattern.to_int()][self.wave_duty_position] *
      Float::from_byte(self.current_volume)
    dac_input / 7.5 - 1.0
  } else {
    0.0
  }
}

///|
priv struct Channel2 {
  mut length_timer : U8
  mut dac_enabled : Bool
  mut enabled : Bool
  mut frequency : U16
  mut length_enabled : Bool
  mut frequency_timer : U16
  mut wave_duty_position : Int
  mut wave_duty_pattern : U8
  mut period_timer : U8
  mut current_volume : U8
  mut initial_volume : U8
  mut is_upwards : Bool
  mut period : U8
} derive(Default)

///|
fn Channel2::emulate_fs_cycle(self : Self, fs : U8) -> Unit {
  if (fs & 0b1) == 0 {
    self.length()
  }
  if fs == 7 {
    self.envelope()
  }
}

///|
fn Channel2::length(self : Self) -> Unit {
  if self.length_enabled && self.length_timer > 0 {
    self.length_timer -= 1
    self.enabled = self.enabled && self.length_timer > 0
  }
}

///|
fn Channel2::envelope(self : Self) -> Unit {
  if self.period != 0 {
    if self.period_timer > 0 {
      self.period_timer -= 1
    }

    if self.period_timer == 0 {
      self.period_timer = self.period

      if (self.current_volume < 0xF && self.is_upwards) ||
        (self.current_volume > 0x0 && !self.is_upwards) {
        if self.is_upwards {
          self.current_volume += 1
        } else {
          self.current_volume -= 1
        }
      }
    }
  }
}

///|
fn Channel2::read_nrxx(self : Self, x : U16) -> U8 {
  match x {
    0 => 0xFF
    1 => (self.wave_duty_pattern << 6) | 0b0011_1111
    2 =>
      (self.initial_volume << 4) | (self.is_upwards.to_u8() << 3) | self.period
    3 => 0xFF
    4 => (self.length_enabled.to_u8() << 6) | 0b1011_1111
    _ => panic()
  }
}

///|
fn Channel2::write_nrxx(self : Self, x : U16, val : U8) -> Unit {
  match x {
    0 => ()
    1 => {
      self.wave_duty_pattern = (val >> 6) & 0x03
      self.length_timer = 64 - (val & 0x3F)
    }
    2 => {
      self.is_upwards = (val & 0x08) > 0
      self.initial_volume = val >> 4
      self.period = val & 0x07
      self.dac_enabled = (val & 0b1111_1000) > 0
      self.enabled = self.enabled && self.dac_enabled
    }
    3 => self.frequency = (self.frequency & 0x0700) | val.to_u16()
    4 => {
      self.frequency = (self.frequency & 0x00FF) | ((val & 0x07).to_u16() << 8)
      self.length_enabled = (val & 0x40) > 0
      if self.length_timer == 0 {
        self.length_timer = 64
      }
      let trigger = (val & 0x80) > 0
      if trigger && self.dac_enabled {
        self.enabled = true
        self.period_timer = self.period
        self.current_volume = self.initial_volume
      }
    }
    _ => panic()
  }
}

///|
fn Channel2::emulate_t_cycle(self : Self) -> Unit {
  if self.frequency_timer == 0 {
    self.frequency_timer = (2048 - self.frequency) * 4
    self.wave_duty_position = (self.wave_duty_position + 1) & 7
  }
  self.frequency_timer -= 1
}

///|
fn Channel2::dac_output(self : Self) -> Float {
  if self.dac_enabled && self.enabled {
    let dac_input = wave_duty[self.wave_duty_pattern.to_int()][self.wave_duty_position] *
      Float::from_byte(self.current_volume)
    dac_input / 7.5 - 1.0
  } else {
    0.0
  }
}

///|
priv struct Channel3 {
  mut length_timer : U16
  mut dac_enabled : Bool
  mut enabled : Bool
  mut frequency : U16
  mut length_enabled : Bool
  mut frequency_timer : U16
  mut wave_duty_position : Int
  mut output_level : U8
  mut volume_shift : U8
  wave_ram : FixedArray[U8]
}

///|
impl Default for Channel3 with default() -> Channel3 {
  {
    length_timer: 0,
    dac_enabled: false,
    enabled: false,
    frequency: 0,
    length_enabled: false,
    frequency_timer: 0,
    wave_duty_position: 0,
    output_level: 0,
    volume_shift: 0,
    wave_ram: FixedArray::make(0x10, 0),
  }
}

///|
fn Channel3::emulate_fs_cycle(self : Self, fs : U8) -> Unit {
  if (fs & 0b1) == 0 {
    self.length()
  }
}

///|
fn Channel3::length(self : Self) -> Unit {
  if self.length_enabled && self.length_timer > 0 {
    self.length_timer -= 1
    self.enabled = self.enabled && self.length_timer > 0
  }
}

///|
fn Channel3::read_wave_ram(self : Self, addr : U16) -> U8 {
  self.wave_ram[addr.to_int()]
}

///|
fn Channel3::write_wave_ram(self : Self, addr : U16, val : U8) -> Unit {
  self.wave_ram[addr.to_int()] = val
}

///|
fn Channel3::read_nrxx(self : Self, x : U16) -> U8 {
  match x {
    0 => (self.dac_enabled.to_u8() << 7) | 0x7F
    1 => 0xFF
    2 => (self.output_level << 5) | 0x9F
    3 => 0xFF
    4 => (self.length_enabled.to_u8() << 6) | 0b1011_1111
    _ => panic()
  }
}

///|
fn Channel3::write_nrxx(self : Self, x : U16, val : U8) -> Unit {
  match x {
    0 => {
      self.dac_enabled = (val & 0x80) > 0
      self.enabled = self.enabled && self.dac_enabled
    }
    1 => self.length_timer = 256 - val.to_u16()
    2 => {
      self.output_level = (val >> 5) & 0x03
      let shifted = self.output_level - 1
      self.volume_shift = if shifted > 4 { 4 } else { shifted }
    }
    3 => self.frequency = (self.frequency & 0x0700) | val.to_u16()
    4 => {
      self.frequency = (self.frequency & 0x00FF) | ((val & 0x07).to_u16() << 8)
      self.length_enabled = (val & 0x40) > 0
      if self.length_timer == 0 {
        self.length_timer = 256
      }
      let trigger = (val & 0x80) > 0
      if trigger && self.dac_enabled {
        self.enabled = true
      }
    }
    _ => panic()
  }
}

///|
fn Channel3::emulate_t_cycle(self : Self) -> Unit {
  if self.frequency_timer == 0 {
    self.frequency_timer = (2048 - self.frequency) * 2
    self.wave_duty_position = (self.wave_duty_position + 1) & 31
  }
  self.frequency_timer -= 1
}

///|
fn Channel3::dac_output(self : Self) -> Float {
  if self.dac_enabled && self.enabled {
    let byte = self.wave_ram[self.wave_duty_position >> 1]
    let shift = (self.wave_duty_position & 1) << 2
    let mut dac_input : U8 = (byte >> shift) & 0x0F
    dac_input = dac_input >> self.volume_shift.to_int()
    Float::from_byte(dac_input) / 7.5 - 1.0
  } else {
    0.0
  }
}

///|
priv struct Channel4 {
  mut length_timer : U8
  mut dac_enabled : Bool
  mut enabled : Bool
  mut length_enabled : Bool
  mut frequency_timer : U16
  mut period_timer : U8
  mut current_volume : U8
  mut initial_volume : U8
  mut is_upwards : Bool
  mut period : U8
  mut lfsr : U16
  mut shift_amount : U8
  mut width_mode : Bool
  mut divisor_code : U8
} derive(Default)

///|
fn Channel4::emulate_fs_cycle(self : Self, fs : U8) -> Unit {
  if (fs & 0b1) == 0 {
    self.length()
  }
  if fs == 7 {
    self.envelope()
  }
}

///|
fn Channel4::length(self : Self) -> Unit {
  if self.length_enabled && self.length_timer > 0 {
    self.length_timer -= 1
    self.enabled = self.enabled && self.length_timer > 0
  }
}

///|
fn Channel4::envelope(self : Self) -> Unit {
  if self.period != 0 {
    if self.period_timer > 0 {
      self.period_timer -= 1
    }

    if self.period_timer == 0 {
      self.period_timer = self.period

      if (self.current_volume < 0xF && self.is_upwards) ||
        (self.current_volume > 0x0 && !self.is_upwards) {
        if self.is_upwards {
          self.current_volume += 1
        } else {
          self.current_volume -= 1
        }
      }
    }
  }
}

///|
fn Channel4::read_nrxx(self : Self, x : U16) -> U8 {
  match x {
    0 => 0xFF
    1 => 0xFF
    2 =>
      (self.initial_volume << 4) | (self.is_upwards.to_u8() << 3) | self.period
    3 =>
      (self.shift_amount << 4) |
      (self.width_mode.to_u8() << 3) |
      self.divisor_code
    4 => (self.length_enabled.to_u8() << 6) | 0b1011_1111
    _ => panic()
  }
}

///|
fn Channel4::write_nrxx(self : Self, x : U16, val : U8) -> Unit {
  match x {
    0 => ()
    1 => self.length_timer = 64 - (val & 0x3F)
    2 => {
      self.is_upwards = (val & 0x08) > 0
      self.initial_volume = val >> 4
      self.period = val & 0x07
      self.dac_enabled = (val & 0b1111_1000) > 0
      self.enabled = self.enabled && self.dac_enabled
    }
    3 => {
      self.shift_amount = (val >> 4) & 0x0F
      self.width_mode = (val & 0x08) > 0
      self.divisor_code = val & 0x07
    }
    4 => {
      self.length_enabled = (val & 0x40) > 0
      if self.length_timer == 0 {
        self.length_timer = 64
      }
      let trigger = (val & 0x80) > 0
      if trigger && self.dac_enabled {
        self.enabled = true
      }
      if trigger {
        self.lfsr = 0x7FFF
        self.period_timer = self.period
        self.current_volume = self.initial_volume
      }
    }
    _ => panic()
  }
}

///|
fn Channel4::emulate_t_cycle(self : Self) -> Unit {
  if self.frequency_timer == 0 {
    let base = @cmp.maximum(8, self.divisor_code.to_int() << 4)
    let timer = base << self.shift_amount.to_int()
    self.frequency_timer = timer.to_uint16()

    let xor : U16 = (self.lfsr & 0b01) ^ ((self.lfsr & 0b10) >> 1)
    self.lfsr = (self.lfsr >> 1) | (xor << 14)
    if self.width_mode {
      self.lfsr = self.lfsr & 0xFFBF
      self.lfsr = self.lfsr | (xor << 6)
    }
  }
  self.frequency_timer -= 1
}

///|
fn Channel4::dac_output(self : Self) -> Float {
  if self.dac_enabled && self.enabled {
    let dac_input = Float::from_int((self.lfsr & 0b01).to_int()) *
      Float::from_byte(self.current_volume)
    dac_input / 7.5 - 1.0
  } else {
    0.0
  }
}
