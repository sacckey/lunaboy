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
  stack_array : FixedArray[StackFrame]
  mut sp : Int
}

///|
impl Default for Ctx with default() -> Ctx {
  Ctx::{
    opcode: 0,
    cb: false,
    stack_array: FixedArray::makei(8, fn(_i) { StackFrame::default() }),
    sp: 0,
  }
}

///|
priv struct Cpu {
  regs : Registers
  ctx : Ctx
}

///|
fn Cpu::new() -> Self {
  Cpu::{ regs: Registers::default(), ctx: Ctx::default() }
}

///|
fn Cpu::emulate_cycle(self : Self, bus : Bus) -> Unit {
  self.decode(bus)
}
