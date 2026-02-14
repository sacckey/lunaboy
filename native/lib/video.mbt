///|
const SCREEN_WIDTH = 160

///|
const SCREEN_HEIGHT = 144

///|
const SCALE = 3

///|
fn[T] as_void_ptr(value : T) -> @sdl.VoidPtr = "%identity"

///|
priv struct Video {
  window : @sdl.SDL_Window
  renderer : @sdl.SDL_Renderer
  texture : @sdl.SDL_Texture
  src_rect : @sdl.SDL_FRect
  dst_rect : @sdl.SDL_FRect
}

///|
fn Video::new(
  window : @sdl.SDL_Window,
  renderer : @sdl.SDL_Renderer,
  texture : @sdl.SDL_Texture,
) -> Self {
  {
    window,
    renderer,
    texture,
    src_rect: @sdl.SDL_FRect::{
      x: 0.0,
      y: 0.0,
      w: Float::from_int(SCREEN_WIDTH),
      h: Float::from_int(SCREEN_HEIGHT),
    },
    dst_rect: @sdl.SDL_FRect::{
      x: 0.0,
      y: 0.0,
      w: Float::from_int(SCREEN_WIDTH * SCALE),
      h: Float::from_int(SCREEN_HEIGHT * SCALE),
    },
  }
}

///|
fn Video::draw(self : Self, pixels : FixedArray[UInt]) -> Unit {
  @sdl.sdl_UpdateTexture(
    self.texture,
    @sdl.SDL_Rect::{ x: 0, y: 0, w: SCREEN_WIDTH, h: SCREEN_HEIGHT },
    as_void_ptr(pixels),
    SCREEN_WIDTH * 4,
  )
  |> ignore
  @sdl.sdl_RenderClear(self.renderer) |> ignore
  @sdl.sdl_RenderTexture(
    self.renderer,
    self.texture,
    self.src_rect,
    self.dst_rect,
  )
  |> ignore
  @sdl.sdl_RenderPresent(self.renderer) |> ignore
}

///|
fn Video::clear(self : Self) -> Unit {
  @sdl.sdl_DestroyTexture(self.texture)
  @sdl.sdl_DestroyRenderer(self.renderer)
  @sdl.sdl_DestroyWindow(self.window)
}
