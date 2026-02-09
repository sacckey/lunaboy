///|
priv trait IO8 {
  read8(Self, Bus, IO8Type) -> U8?
  write8(Self, Bus, IO8Type, U8) -> Unit?
}

///|
priv trait IO16 {
  read16(Self, Bus, IO16Type) -> U16?
  write16(Self, Bus, IO16Type, U16) -> Unit?
}

///|
enum Reg8 {
  A
  B
  C
  D
  E
  H
  L
} derive(Debug)

///|
enum Reg16 {
  AF
  BC
  DE
  HL
  SP
} derive(Debug)

///|
enum Indirect {
  BC
  DE
  HL
  CFF
  HLD
  HLI
} derive(Debug)

///|
enum Direct8 {
  D
  DFF
} derive(Debug)

///|
enum Cond {
  NZ
  Z
  NC
  C
} derive(Debug)

///|
priv enum IO8Type {
  Reg8(Reg8)
  Imm8
  Indirect(Indirect)
  Direct8(Direct8)
}

///|
priv enum IO16Type {
  Reg16(Reg16)
  Imm16
  Direct16
}

///|
impl IO8 for Cpu with read8(self, bus, src) {
  match src {
    IO8Type::Reg8(reg) =>
      Some(
        match reg {
          Reg8::A => self.regs.a
          Reg8::B => self.regs.b
          Reg8::C => self.regs.c
          Reg8::D => self.regs.d
          Reg8::E => self.regs.e
          Reg8::H => self.regs.h
          Reg8::L => self.regs.l
        },
      )
    IO8Type::Imm8 => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          state.val.u8 = bus.read(self.regs.pc)
          state.val.step = 1
          self.regs.pc = self.regs.pc + 1
          None
        }
        1 => {
          state.val.step = 0
          Some(state.val.u8)
        }
        _ => panic()
      }
    }
    IO8Type::Indirect(ind) => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          let u8 = match ind {
            BC => bus.read(self.regs.bc())
            DE => bus.read(self.regs.de())
            HL => bus.read(self.regs.hl())
            CFF => bus.read(0xFF00 | self.regs.c.to_u16())
            HLD => {
              let addr = self.regs.hl()
              self.regs.write_hl(addr - 1)
              bus.read(addr)
            }
            HLI => {
              let addr = self.regs.hl()
              self.regs.write_hl(addr + 1)
              bus.read(addr)
            }
          }
          state.val.u8 = u8
          state.val.step = 1
          None
        }
        1 => {
          state.val.step = 0
          Some(state.val.u8)
        }
        _ => panic()
      }
    }
    IO8Type::Direct8(dir) => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.step = 1
          None
        }
        1 => {
          let lo = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          match dir {
            Direct8::D => {
              state.val.u8 = lo
              ignore(
                self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }),
              )
              state.val.step = 2
            }
            Direct8::DFF => {
              state.val.u8 = bus.read(0xFF00 | lo.to_u16())
              state.val.step = 3
            }
          }
          None
        }
        2 => {
          let hi = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          state.val.u8 = bus.read((hi.to_u16() << 8) | state.val.u8.to_u16())
          state.val.step = 3
          None
        }
        3 => {
          state.val.step = 0
          Some(state.val.u8)
        }
        _ => panic()
      }
    }
  }
}

///|
impl IO8 for Cpu with write8(self, bus, dst, val) {
  match dst {
    IO8Type::Reg8(reg) =>
      Some(
        match reg {
          Reg8::A => self.regs.a = val
          Reg8::B => self.regs.b = val
          Reg8::C => self.regs.c = val
          Reg8::D => self.regs.d = val
          Reg8::E => self.regs.e = val
          Reg8::H => self.regs.h = val
          Reg8::L => self.regs.l = val
        },
      )
    IO8Type::Imm8 => panic()
    IO8Type::Indirect(ind) => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          match ind {
            BC => bus.write(self.regs.bc(), val)
            DE => bus.write(self.regs.de(), val)
            HL => bus.write(self.regs.hl(), val)
            CFF => bus.write(0xFF00 | self.regs.c.to_u16(), val)
            HLD => {
              let addr = self.regs.hl()
              self.regs.write_hl(addr - 1)
              bus.write(addr, val)
            }
            HLI => {
              let addr = self.regs.hl()
              self.regs.write_hl(addr + 1)
              bus.write(addr, val)
            }
          }
          state.val.step = 1
          None
        }
        1 => {
          state.val.step = 0
          Some(())
        }
        _ => panic()
      }
    }
    IO8Type::Direct8(dir) => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.step = 1
          None
        }
        1 => {
          let lo = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          match dir {
            Direct8::D => {
              state.val.u8 = lo
              ignore(
                self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }),
              )
              state.val.step = 2
            }
            Direct8::DFF => {
              bus.write(0xFF00 | lo.to_u16(), val)
              state.val.step = 3
            }
          }
          None
        }
        2 => {
          let hi = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          bus.write((hi.to_u16() << 8) | state.val.u8.to_u16(), val)
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
  }
}

///|
impl IO16 for Cpu with read16(self, bus, src) {
  match src {
    IO16Type::Reg16(reg) =>
      Some(
        match reg {
          Reg16::AF => self.regs.af()
          Reg16::BC => self.regs.bc()
          Reg16::DE => self.regs.de()
          Reg16::HL => self.regs.hl()
          Reg16::SP => self.regs.sp
        },
      )
    IO16Type::Imm16 => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.step = 1
          None
        }
        1 => {
          let lo = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.u8 = lo
          state.val.step = 2
          None
        }
        2 => {
          let hi = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          state.val.step = 0
          Some((hi.to_u16() << 8) | state.val.u8.to_u16())
        }
        _ => panic()
      }
    }
    IO16Type::Direct16 => panic()
  }
}

///|
impl IO16 for Cpu with write16(self, bus, dst, val) {
  match dst {
    IO16Type::Reg16(reg) =>
      Some(
        match reg {
          Reg16::AF => self.regs.write_af(val)
          Reg16::BC => self.regs.write_bc(val)
          Reg16::DE => self.regs.write_de(val)
          Reg16::HL => self.regs.write_hl(val)
          Reg16::SP => self.regs.sp = val
        },
      )
    IO16Type::Imm16 => panic()
    IO16Type::Direct16 => {
      let state = self.current_state()
      match state.val.step {
        0 => {
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.step = 1
          None
        }
        1 => {
          state.val.u8 = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          ignore(self.with_child_state(fn() { self.read8(bus, IO8Type::Imm8) }))
          state.val.step = 2
          None
        }
        2 => {
          let hi = self
            .with_child_state(fn() { self.read8(bus, IO8Type::Imm8) })
            .unwrap()
          state.val.u16 = (hi.to_u16() << 8) | state.val.u8.to_u16()
          bus.write(state.val.u16, val.to_u8())
          state.val.step = 3
          None
        }
        3 => {
          bus.write(state.val.u16 + 1, (val >> 8).to_u8())
          state.val.step = 4
          None
        }
        4 => {
          state.val.step = 0
          Some(())
        }
        _ => panic()
      }
    }
  }
}
