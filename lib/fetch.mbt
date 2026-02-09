///|
fn Cpu::fetch(self : Self, bus : Bus) -> Unit {
  self.ctx.opcode = bus.read(self.regs.pc)
  self.regs.pc = self.regs.pc + 1
  self.ctx.cb = false
}
