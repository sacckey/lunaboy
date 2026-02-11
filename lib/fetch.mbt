///|
fn Cpu::fetch(self : Self, bus : Bus) -> Unit {
  self.ctx.opcode = bus.read(self.interrupts, self.regs.pc)
  if self.interrupts.ime && self.interrupts.get_interrupt() > 0 {
    self.ctx.in_isr = true
  } else {
    self.regs.pc = self.regs.pc + 1
    self.ctx.in_isr = false
  }
  self.ctx.cb = false
}
