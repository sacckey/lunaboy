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
      bus.write(self.interrupts, self.regs.sp, (val >> 8).to_u8())
      state.val.u8 = val.to_u8()
      state.val.step = 2
      None
    }
    2 => {
      self.regs.sp -= 1
      bus.write(self.interrupts, self.regs.sp, state.val.u8)
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
      state.val.u8 = bus.read(self.interrupts, self.regs.sp)
      self.regs.sp += 1
      state.val.step = 1
      None
    }
    1 => {
      let hi = bus.read(self.interrupts, self.regs.sp)
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

///|
fn Cpu::reti(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.pop16(bus) }) is Some(u16) {
        self.regs.pc = u16
        state.val.step = 1
      }
    1 => {
      self.interrupts.ime = true
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::ei(self : Self, bus : Bus) -> Unit {
  self.fetch(bus)
  self.interrupts.ime = true
}

///|
fn Cpu::di(self : Self, bus : Bus) -> Unit {
  self.interrupts.ime = false
  self.fetch(bus)
}

///|
fn Cpu::halt(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.interrupts.get_interrupt() > 0 {
        self.fetch(bus)
      } else {
        state.val.step = 1
      }
    1 =>
      if self.interrupts.get_interrupt() > 0 {
        state.val.step = 0
        self.fetch(bus)
      }
    _ => panic()
  }
}

///|
fn Cpu::stop(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
        is Some(_) {
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
fn Cpu::rlca(self : Self, bus : Bus) -> Unit {
  let bit7 = (self.regs.a & 0x80) > 0
  self.regs.a = (self.regs.a << 1) | bit7.to_u8()
  self.regs.set_zf(false)
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(bit7)
  self.fetch(bus)
}

///|
fn Cpu::rrca(self : Self, bus : Bus) -> Unit {
  let bit0 = (self.regs.a & 0x01) > 0
  self.regs.a = (self.regs.a >> 1) | (bit0.to_u8() << 7)
  self.regs.set_zf(false)
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(bit0)
  self.fetch(bus)
}

///|
fn Cpu::rla(self : Self, bus : Bus) -> Unit {
  let carry = self.regs.cf().to_u8()
  let bit7 = (self.regs.a & 0x80) > 0
  self.regs.a = (self.regs.a << 1) | carry
  self.regs.set_zf(false)
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(bit7)
  self.fetch(bus)
}

///|
fn Cpu::rra(self : Self, bus : Bus) -> Unit {
  let carry = self.regs.cf().to_u8()
  let bit0 = (self.regs.a & 0x01) > 0
  self.regs.a = (self.regs.a >> 1) | (carry << 7)
  self.regs.set_zf(false)
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(bit0)
  self.fetch(bus)
}

///|
fn Cpu::daa(self : Self, bus : Bus) -> Unit {
  let mut a = self.regs.a
  let mut adjust : U8 = 0
  let mut cf = self.regs.cf()

  if !self.regs.nf() {
    if cf || a > 0x99 {
      adjust = adjust | 0x60
      cf = true
    }
    if self.regs.hf() || (a & 0x0F) > 0x09 {
      adjust = adjust | 0x06
    }
    a = a + adjust
  } else {
    if cf {
      adjust = adjust | 0x60
    }
    if self.regs.hf() {
      adjust = adjust | 0x06
    }
    a = a - adjust
  }

  self.regs.a = a
  self.regs.set_zf(a == 0)
  self.regs.set_hf(false)
  self.regs.set_cf(cf)
  self.fetch(bus)
}

///|
fn Cpu::cpl(self : Self, bus : Bus) -> Unit {
  self.regs.a = self.regs.a.lnot()
  self.regs.set_nf(true)
  self.regs.set_hf(true)
  self.fetch(bus)
}

///|
fn Cpu::scf(self : Self, bus : Bus) -> Unit {
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(true)
  self.fetch(bus)
}

///|
fn Cpu::ccf(self : Self, bus : Bus) -> Unit {
  self.regs.set_nf(false)
  self.regs.set_hf(false)
  self.regs.set_cf(!self.regs.cf())
  self.fetch(bus)
}

///|
fn Cpu::add(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    let a = self.regs.a
    let res = a + u8
    self.regs.a = res
    self.regs.set_zf(res == 0)
    self.regs.set_nf(false)
    self.regs.set_hf((a & 0x0F) + (u8 & 0x0F) > 0x0F)
    self.regs.set_cf(res < a)
    self.fetch(bus)
  }
}

///|
fn Cpu::adc(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    let a = self.regs.a
    let carry = self.regs.cf().to_u8()
    let res = a + u8 + carry
    self.regs.a = res
    self.regs.set_zf(res == 0)
    self.regs.set_nf(false)
    self.regs.set_hf((a & 0x0F) + (u8 & 0x0F) + carry > 0x0F)
    self.regs.set_cf(a.to_int() + u8.to_int() + carry.to_int() > 0xFF)
    self.fetch(bus)
  }
}

///|
fn Cpu::sub(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    let a = self.regs.a
    let res = a - u8
    self.regs.a = res
    self.regs.set_zf(res == 0)
    self.regs.set_nf(true)
    self.regs.set_hf((a & 0x0F) < (u8 & 0x0F))
    self.regs.set_cf(a < u8)
    self.fetch(bus)
  }
}

///|
fn Cpu::sbc(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    let a = self.regs.a
    let carry = self.regs.cf().to_u8()
    let res = a - u8 - carry
    self.regs.a = res
    self.regs.set_zf(res == 0)
    self.regs.set_nf(true)
    self.regs.set_hf((a & 0x0F) < (u8 & 0x0F) + carry)
    self.regs.set_cf(a.to_int() < u8.to_int() + carry.to_int())
    self.fetch(bus)
  }
}

///|
fn Cpu::band(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    self.regs.a = self.regs.a & u8
    self.regs.set_zf(self.regs.a == 0)
    self.regs.set_nf(false)
    self.regs.set_hf(true)
    self.regs.set_cf(false)
    self.fetch(bus)
  }
}

///|
fn Cpu::xor(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    self.regs.a = self.regs.a ^ u8
    self.regs.set_zf(self.regs.a == 0)
    self.regs.set_nf(false)
    self.regs.set_hf(false)
    self.regs.set_cf(false)
    self.fetch(bus)
  }
}

///|
fn Cpu::or(self : Self, bus : Bus, src : IO8Type) -> Unit {
  if self.read8(bus, src) is Some(u8) {
    self.regs.a = self.regs.a | u8
    self.regs.set_zf(self.regs.a == 0)
    self.regs.set_nf(false)
    self.regs.set_hf(false)
    self.regs.set_cf(false)
    self.fetch(bus)
  }
}

///|
fn Cpu::add16(self : Self, bus : Bus, dst : IO16Type, src : IO16Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, src) }) is Some(u16) {
        state.val.u16 = u16
        state.val.step = 1
        self.add16(bus, dst, src)
      }
    1 => {
      let lhs = self.read16(bus, dst).unwrap()
      let rhs = state.val.u16
      let res = lhs + rhs
      self.regs.set_nf(false)
      self.regs.set_hf((lhs & 0x0FFF) + (rhs & 0x0FFF) > 0x0FFF)
      self.regs.set_cf(res < lhs)
      ignore(self.write16(bus, dst, res))
      state.val.step = 2
    }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::jp(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, IO16Type::Imm16) })
        is Some(u16) {
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

///|
fn Cpu::jp_c(self : Self, bus : Bus, c : Cond) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, IO16Type::Imm16) })
        is Some(u16) {
        state.val.step = 1
        if self.cond(c) {
          self.regs.pc = u16
        } else {
          self.jp_c(bus, c)
        }
      }
    1 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::call_c(self : Self, bus : Bus, c : Cond) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read16(bus, IO16Type::Imm16) })
        is Some(u16) {
        state.val.u16 = u16
        state.val.u8 = self.cond(c).to_u8()
        state.val.step = 1
        self.call_c(bus, c)
      }
    1 =>
      if state.val.u8 == 0 {
        state.val.step = 2
        self.call_c(bus, c)
      } else if self.with_child_state(fn() { self.push16(bus, self.regs.pc) })
        is Some(_) {
        self.regs.pc = state.val.u16
        state.val.step = 2
        self.call_c(bus, c)
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::ret_c(self : Self, bus : Bus, c : Cond) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 => {
      state.val.step = if self.cond(c) { 1 } else { 2 }
    }
    1 =>
      if self.with_child_state(fn() { self.pop16(bus) }) is Some(u16) {
        self.regs.pc = u16
        state.val.step = 2
      }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::rst(self : Self, bus : Bus, addr : U16) -> Unit {
  if self.with_child_state(fn() { self.push16(bus, self.regs.pc) })
    is Some(_) {
    self.regs.pc = addr
    self.fetch(bus)
  }
}

///|
fn Cpu::add_sp(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
        is Some(u8) {
        state.val.u8 = u8
        state.val.step = 1
      }
    1 => {
      let sp = self.regs.sp
      let u8 = state.val.u8
      self.regs.set_zf(false)
      self.regs.set_nf(false)
      self.regs.set_hf((sp & 0x000F) + (u8.to_u16() & 0x000F) > 0x000F)
      self.regs.set_cf((sp & 0x00FF) + u8.to_u16() > 0x00FF)
      self.regs.sp = sp + u8.to_i8().reinterpret_as_uint16()
      state.val.step = 2
    }
    2 => {
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}

///|
fn Cpu::jp_hl(self : Self, bus : Bus) -> Unit {
  self.regs.pc = self.regs.hl()
  self.fetch(bus)
}

///|
fn Cpu::ld_hl_sp(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
        is Some(u8) {
        let sp = self.regs.sp
        self.regs.set_zf(false)
        self.regs.set_nf(false)
        self.regs.set_hf((sp & 0x000F) + (u8.to_u16() & 0x000F) > 0x000F)
        self.regs.set_cf((sp & 0x00FF) + u8.to_u16() > 0x00FF)
        self.regs.write_hl(sp + u8.to_i8().reinterpret_as_uint16())
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
fn Cpu::ld_sp_hl(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 => {
      self.regs.sp = self.regs.hl()
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
fn Cpu::rlc(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let bit7 = (u8 & 0x80) > 0
        let res = (u8 << 1) | bit7.to_u8()
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit7)
        state.val.u8 = res
        state.val.step = 1
        self.rlc(bus, src)
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
fn Cpu::rrc(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let bit0 = (u8 & 0x01) > 0
        let res = (u8 >> 1) | (bit0.to_u8() << 7)
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit0)
        state.val.u8 = res
        state.val.step = 1
        self.rrc(bus, src)
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
fn Cpu::rr(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let carry = self.regs.cf().to_u8()
        let bit0 = (u8 & 0x01) > 0
        let res = (u8 >> 1) | (carry << 7)
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit0)
        state.val.u8 = res
        state.val.step = 1
        self.rr(bus, src)
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
fn Cpu::sla(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let bit7 = (u8 & 0x80) > 0
        let res = u8 << 1
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit7)
        state.val.u8 = res
        state.val.step = 1
        self.sla(bus, src)
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
fn Cpu::sra(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let bit0 = (u8 & 0x01) > 0
        let res = (u8 >> 1) | (u8 & 0x80)
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit0)
        state.val.u8 = res
        state.val.step = 1
        self.sra(bus, src)
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
fn Cpu::swap(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let res = (u8 << 4) | (u8 >> 4)
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(false)
        state.val.u8 = res
        state.val.step = 1
        self.swap(bus, src)
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
fn Cpu::srl(self : Self, bus : Bus, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        let bit0 = (u8 & 0x01) > 0
        let res = u8 >> 1
        self.regs.set_zf(res == 0)
        self.regs.set_nf(false)
        self.regs.set_hf(false)
        self.regs.set_cf(bit0)
        state.val.u8 = res
        state.val.step = 1
        self.srl(bus, src)
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
fn Cpu::res(self : Self, bus : Bus, bit : Int, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        state.val.u8 = u8 & (1 << bit).to_u8().lnot()
        state.val.step = 1
        self.res(bus, bit, src)
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
fn Cpu::set(self : Self, bus : Bus, bit : Int, src : IO8Type) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.read8(bus, src) }) is Some(u8) {
        state.val.u8 = u8 | (1 << bit).to_u8()
        state.val.step = 1
        self.set(bus, bit, src)
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
