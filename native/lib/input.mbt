///|
const SDL_SCANCODE_W : Int = 26

///|
const SDL_SCANCODE_A : Int = 4

///|
const SDL_SCANCODE_S : Int = 22

///|
const SDL_SCANCODE_D : Int = 7

///|
const SDL_SCANCODE_J : Int = 13

///|
const SDL_SCANCODE_K : Int = 14

///|
const SDL_SCANCODE_U : Int = 24

///|
const SDL_SCANCODE_I : Int = 12

///|
extern "C" fn read_keys4(a : Int, b : Int, c : Int, d : Int) -> @core.U8 = "lunaboy_read_keys4"

///|
priv struct Input {
  mut direction_pressed : @core.U8
  mut action_pressed : @core.U8
}

///|
fn Input::new() -> Self {
  { direction_pressed: 0, action_pressed: 0 }
}

///|
fn Input::update(self : Self) -> Unit {
  @sdl.sdl_PumpEvents()

  self.direction_pressed = read_keys4(
    SDL_SCANCODE_D,
    SDL_SCANCODE_A,
    SDL_SCANCODE_W,
    SDL_SCANCODE_S,
  )
  self.action_pressed = read_keys4(
    SDL_SCANCODE_K,
    SDL_SCANCODE_J,
    SDL_SCANCODE_U,
    SDL_SCANCODE_I,
  )
}

///|
fn Input::direction_mask(self : Self) -> @core.U8 {
  self.direction_pressed
}

///|
fn Input::action_mask(self : Self) -> @core.U8 {
  self.action_pressed
}
