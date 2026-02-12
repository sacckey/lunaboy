///|
const SCREEN_WIDTH = 160

///|
const SCREEN_HEIGHT = 144

///|
const SCALE = 3

///|
priv struct Lcd {
  window : SDL_Window
  renderer : SDL_Renderer
  texture : SDL_Texture
}

///|
fn Lcd::new() -> Self {
  let window = sdl_create_window("Luna Boy", SCREEN_WIDTH, SCREEN_HEIGHT, SCALE)
  let renderer = sdl_create_renderer(window)
  let texture = sdl_create_texture(renderer, SCREEN_WIDTH, SCREEN_HEIGHT)
  Lcd::{ window, renderer, texture }
}

///|
fn Lcd::draw(self : Self, pixels : FixedArray[UInt]) -> Unit {
  sdl_draw_lcd(
    self.renderer,
    self.texture,
    pixels,
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
    SCALE,
  )
}

///|
fn Lcd::clear(self : Self) -> Unit {
  sdl_destroy_texture(self.texture)
  sdl_destroy_renderer(self.renderer)
  sdl_destroy_window(self.window)
}
