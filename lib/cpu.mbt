///|
struct StackFrame {
  mut step : U8
  mut u8 : U8
  mut u16 : U16
} derive(Show, Default)

///|
priv struct Ctx {
  mut opcode : U8
  mut cb : Bool
  mut in_isr : Bool
  state_stack : FixedArray[StackFrame]
  mut state_idx : Int
}

///|
impl Default for Ctx with default() -> Ctx {
  Ctx::{
    opcode: 0,
    cb: false,
    in_isr: false,
    state_stack: FixedArray::makei(4, fn(_i) { StackFrame::default() }),
    state_idx: 0,
  }
}

///|
priv struct Cpu {
  regs : Registers
  interrupts : Interrupts
  ctx : Ctx
}

///|
fn Cpu::new() -> Self {
  Cpu::{
    regs: Registers::default(),
    interrupts: Interrupts::default(),
    ctx: Ctx::default(),
  }
}

///|
fn Cpu::emulate_cycle(self : Self, bus : Bus) -> Unit {
  if self.ctx.in_isr {
    self.call_isr(bus)
  } else {
    self.decode(bus)
  }
}

///|
fn Cpu::current_state(self : Self) -> Ref[StackFrame] {
  Ref::new(self.ctx.state_stack[self.ctx.state_idx])
}

///|
fn[T] Cpu::with_child_state(self : Self, f : () -> T) -> T {
  self.ctx.state_idx += 1
  let ret = f()
  self.ctx.state_idx -= 1
  ret
}

///|
fn Cpu::call_isr(self : Self, bus : Bus) -> Unit {
  let state = self.current_state()
  match state.val.step {
    0 =>
      if self.with_child_state(fn() { self.push16(bus, self.regs.pc) })
        is Some(_) {
        let flag = (1 << self.interrupts.get_interrupt().trailing_zeros()).to_u8()
        self.interrupts.int_flags = self.interrupts.int_flags & flag.lnot()

        self.regs.pc = match flag {
          VBLANK => 0x40
          STAT => 0x48
          TIMER => 0x50
          SERIAL => 0x58
          JOYPAD => 0x60
          _ => panic()
        }
        state.val.step = 1
      }
    1 => {
      self.interrupts.ime = false
      state.val.step = 0
      self.fetch(bus)
    }
    _ => panic()
  }
}
