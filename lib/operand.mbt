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
      let stackRef = self.current_state()
      match stackRef.val.step {
        0 => {
          stackRef.val.u8 = bus.read(self.regs.pc)
          stackRef.val.step = 1
          self.regs.pc = self.regs.pc + 1
          None
        }
        1 => {
          stackRef.val.step = 0
          Some(stackRef.val.u8)
        }
        _ => panic()
      }
    }
    IO8Type::Indirect(ind) => {
      let stackRef = self.current_state()
      match stackRef.val.step {
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
          stackRef.val.u8 = u8
          stackRef.val.step = 1
          None
        }
        1 => {
          stackRef.val.step = 0
          Some(stackRef.val.u8)
        }
        _ => panic()
      }
    }
    IO8Type::Direct8(dir) => {
      let stackRef = self.current_state()
      match stackRef.val.step {
        0 => {
          self.ctx.state_idx += 1
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.step = 1
          None
        }
        1 => {
          self.ctx.state_idx += 1
          let lo = self.read8(bus, IO8Type::Imm8).unwrap()
          match dir {
            Direct8::D => {
              stackRef.val.u8 = lo
              ignore(self.read8(bus, IO8Type::Imm8))
              stackRef.val.step = 2
            }
            Direct8::DFF => {
              stackRef.val.u8 = bus.read(0xFF00 | lo.to_u16())
              stackRef.val.step = 3
            }
          }
          self.ctx.state_idx -= 1
          None
        }
        2 => {
          self.ctx.state_idx += 1
          let hi = self.read8(bus, IO8Type::Imm8).unwrap()
          self.ctx.state_idx -= 1
          stackRef.val.u8 = bus.read(
            (hi.to_u16() << 8) | stackRef.val.u8.to_u16(),
          )
          stackRef.val.step = 3
          None
        }
        3 => {
          stackRef.val.step = 0
          Some(stackRef.val.u8)
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
      let stackRef = self.current_state()
      match stackRef.val.step {
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
          stackRef.val.step = 1
          None
        }
        1 => {
          stackRef.val.step = 0
          Some(())
        }
        _ => panic()
      }
    }
    IO8Type::Direct8(dir) => {
      let stackRef = self.current_state()
      match stackRef.val.step {
        0 => {
          self.ctx.state_idx += 1
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.step = 1
          None
        }
        1 => {
          self.ctx.state_idx += 1
          let lo = self.read8(bus, IO8Type::Imm8).unwrap()
          match dir {
            Direct8::D => {
              stackRef.val.u8 = lo
              ignore(self.read8(bus, IO8Type::Imm8))
              stackRef.val.step = 2
            }
            Direct8::DFF => {
              bus.write(0xFF00 | lo.to_u16(), val)
              stackRef.val.step = 3
            }
          }
          self.ctx.state_idx -= 1
          None
        }
        2 => {
          self.ctx.state_idx += 1
          let hi = self.read8(bus, IO8Type::Imm8).unwrap()
          self.ctx.state_idx -= 1
          bus.write((hi.to_u16() << 8) | stackRef.val.u8.to_u16(), val)
          stackRef.val.step = 3
          None
        }
        3 => {
          stackRef.val.step = 0
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
      let stackRef = self.current_state()
      match stackRef.val.step {
        0 => {
          self.ctx.state_idx += 1
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.step = 1
          None
        }
        1 => {
          self.ctx.state_idx += 1
          let lo = self.read8(bus, IO8Type::Imm8).unwrap()
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.u8 = lo
          stackRef.val.step = 2
          None
        }
        2 => {
          self.ctx.state_idx += 1
          let hi = self.read8(bus, IO8Type::Imm8).unwrap()
          self.ctx.state_idx -= 1
          stackRef.val.step = 0
          Some((hi.to_u16() << 8) | stackRef.val.u8.to_u16())
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
      let stackRef = self.current_state()
      match stackRef.val.step {
        0 => {
          self.ctx.state_idx += 1
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.step = 1
          None
        }
        1 => {
          self.ctx.state_idx += 1
          stackRef.val.u8 = self.read8(bus, IO8Type::Imm8).unwrap()
          ignore(self.read8(bus, IO8Type::Imm8))
          self.ctx.state_idx -= 1
          stackRef.val.step = 2
          None
        }
        2 => {
          self.ctx.state_idx += 1
          let hi = self.read8(bus, IO8Type::Imm8).unwrap()
          self.ctx.state_idx -= 1
          stackRef.val.u16 = (hi.to_u16() << 8) | stackRef.val.u8.to_u16()
          bus.write(stackRef.val.u16, val.to_u8())
          stackRef.val.step = 3
          None
        }
        3 => {
          bus.write(stackRef.val.u16 + 1, (val >> 8).to_u8())
          stackRef.val.step = 4
          None
        }
        4 => {
          stackRef.val.step = 0
          Some(())
        }
        _ => panic()
      }
    }
  }
}
