///|
priv struct Joypad {
  mut mode : U8
  mut action : U8
  mut direction : U8
}

///|
fn Joypad::new() -> Joypad {
  Joypad::{ mode: 0, action: 0xFF, direction: 0xFF }
}

///|
fn Joypad::read(self : Self) -> U8 {
  let mut ret = (0xCF : U8) | self.mode
  if (ret & 0x10) == 0 {
    ret = ret & self.direction
  }
  if (ret & 0x20) == 0 {
    ret = ret & self.action
  }

  ret
}

///|
fn Joypad::write(self : Self, _ : U16, val : U8) -> Unit {
  self.mode = 0x30 & val
}

///|
fn Joypad::direction_button(
  self : Self,
  input : U8,
  interrupts : Interrupts,
) -> Unit {
  let old = self.direction
  self.direction = input

  if (old & input.lnot() & 0x0F) != 0 {
    interrupts.irq(JOYPAD)
  }
}

///|
fn Joypad::action_button(
  self : Self,
  input : U8,
  interrupts : Interrupts,
) -> Unit {
  let old = self.action
  self.action = input

  if (old & input.lnot() & 0x0F) != 0 {
    interrupts.irq(JOYPAD)
  }
}
