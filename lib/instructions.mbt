///|
fn Cpu::nop(self : Self, bus : Bus) -> Unit {
  self.fetch(bus)
}

///|
fn Cpu::ld(self : Self, bus : Bus, dst : IO8Type, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        state.val.u8 = u8
        state.val.step = 1
        self.ld(bus, dst, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write8(bus, dst, state.val.u8) })
        is Some(_) {
        state.val.step = 2
        self.ld(bus, dst, src)
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::cp(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    self.regs.set_zf(self.regs.a == u8)
    self.regs.set_nf(true)
    self.regs.set_hf((self.regs.a & 0x0F) < (u8 & 0x0F))
    self.regs.set_cf(self.regs.a < u8)
    self.fetch(bus)
  }
}

///|
fn Cpu::inc(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let res = u8 + 1
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf((u8 & 0x0F) == 0x0F)
        state.val.u8 = res
        state.val.step = 1
        self.inc(bus, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write8(bus, src, state.val.u8) })
        is Some(_) {
        state.val.step = 0
        self.fetch(bus)
      }
    _ => panic()
  }
}

///|
fn Cpu::ld16(self : Self, bus : Bus, dst : IO16Type, src : IO16Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, src) }) is Some(u16) {
        state.val.u16 = u16
        state.val.step = 1
        self.ld16(bus, dst, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write16(bus, dst, state.val.u16) })
        is Some(_) {
        state.val.step = 2
        self.ld16(bus, dst, src)
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::inc16(self : Self, bus : Bus, src : IO16Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, src) }) is Some(u16) {
        state.val.u16 = u16 + 1
        state.val.step = 1
        self.inc16(bus, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write16(bus, src, state.val.u16) })
        is Some(_) {
        state.val.step = 2
        return ()
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::dec(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let res = u8 - 1
        self.regs.set_zf(res == 0)
        self.regs.set_nf(true)
        self.regs.set_hf((u8 & 0x0F) == 0x00)
        state.val.u8 = res
        state.val.step = 1
        self.dec(bus, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write8(bus, src, state.val.u8) })
        is Some(_) {
        state.val.step = 0
        self.fetch(bus)
      }
    _ => panic()
  }
}

///|
fn Cpu::dec16(self : Self, bus : Bus, src : IO16Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, src) }) is Some(u16) {
        state.val.u16 = u16 - 1
        state.val.step = 1
        self.dec16(bus, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write16(bus, src, state.val.u16) })
        is Some(_) {
        state.val.step = 2
        return ()
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::rl(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let res = (u8 << 1) | self.regs.cf().to_u8()
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf((u8 & 0x80) > 0)
        state.val.u8 = res
        state.val.step = 1
        self.rl(bus, src)
      }
    1 =>
      if self.with_child_state(fn() { self.write8(bus, src, state.val.u8) })
        is Some(_) {
        state.val.step = 0
        self.fetch(bus)
      }
    _ => panic()
  }
}

///|
fn Cpu::bit(self : Self, bus : Bus, bit : Int, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    let bit_val = u8 & (1 << bit)
    self.regs.set_zf(bit_val == 0)
    self.regs.set_nf(false)
    self.regs.set_hf(true)
    self.fetch(bus)
  }
}

///|
fn Cpu::push16(self : Self, bus : Bus, val : U16) -> Unit? {
  let state = self.current_state()
  match state.val.step {
    0 => {
      state.val.step = 1
      None
    }
    1 => {
      self.regs.sp -= 1
      bus.write(self.regs.sp, (val >> 8).to_u8())
      state.val.u8 = val.to_u8()
      state.val.step = 2
      None
    }
    2 => {
      self.regs.sp -= 1
      bus.write(self.regs.sp, state.val.u8)
      state.val.step = 3
      None
    }
    3 => {
      state.val.step = 0
      Some(())
    }
    _ => panic()
  }
}

///|
fn Cpu::push(self : Self, bus : Bus, src : Reg16) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 => {
      state.val.u16 = self.read16(bus, IO16Type::Reg16(src)).unwrap()
      state.val.step = 1
      self.push(bus, src)
    }
    1 =>
      if self.with_child_state(fn() { self.push16(bus, state.val.u16) })
        is Some(_) {
        state.val.step = 2
        self.push(bus, src)
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::pop16(self : Self, bus : Bus) -> U16? {
  let state = self.current_state()
  match state.val.step {
    0 => {
      state.val.u8 = bus.read(self.regs.sp)
      self.regs.sp += 1
      state.val.step = 1
      None
    }
    1 => {
      let hi = bus.read(self.regs.sp)
      self.regs.sp += 1
      state.val.u16 = (hi.to_u16() << 8) | state.val.u8.to_u16()
      state.val.step = 2
      None
    }
    2 => {
      state.val.step = 0
      Some(state.val.u16)
    }
    _ => panic()
  }
}

///|
fn Cpu::pop(self : Self, bus : Bus, dst : Reg16) -> Unit {
  if self.pop16(bus) is Some(u16) {
    ignore(self.write16(bus, IO16Type::Reg16(dst), u16))
    self.fetch(bus)
  }
}

///|
fn Cpu::jr(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
        is Some(u8) {
        self.regs.pc += u8.to_i8().reinterpret_as_uint16()
        state.val.step = 1
      }
    1 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::cond(self : Self, cond : Cond) -> Bool {
  match cond {
    Cond::NZ => !self.regs.zf()
    Cond::Z => self.regs.zf()
    Cond::NC => !self.regs.cf()
    Cond::C => self.regs.cf()
  }
}

///|
fn Cpu::jr_c(self : Self, bus : Bus, c : Cond) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
        is Some(u8) {
        state.val.step = 1
        if self.cond(c) {
          self.regs.pc += u8.to_i8().reinterpret_as_uint16()
          return ()
        }
        self.jr_c(bus, c)
      }
    1 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::call(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, IO16Type::Imm16) })
        is Some(u16) {
        state.val.u16 = u16
        state.val.step = 1
        self.call(bus)
      }
    1 =>
      if self.with_child_state(fn() { self.push16(bus, self.regs.pc) })
        is Some(_) {
        self.regs.pc = state.val.u16
        state.val.step = 0
        self.fetch(bus)
      }
    _ => panic()
  }
}

///|
fn Cpu::ret(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.pop16(bus) }) is Some(u16) {
        self.regs.pc = u16
        state.val.step = 1
      }
    1 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}
