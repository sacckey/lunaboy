///|
const SCREEN_WIDTH = 160

///|
const SCREEN_HEIGHT = 144

///|
const SCALE = 3

///|
fn[T] as_void_ptr(value : T) -> @sdl.VoidPtr = "%identity"

///|
priv struct Lcd {
  _window : @sdl.SDL_Window
  renderer : @sdl.SDL_Renderer
  texture : @sdl.SDL_Texture
  event : @sdl.SDL_Event
}

///|
fn Lcd::new() -> Self {
  @sdl.sdl_Init(@sdl.SDL_INIT_VIDEO) |> ignore

  let window = @sdl.sdl_CreateWindow(
    "Luna Boy",
    SCREEN_WIDTH * SCALE,
    SCREEN_HEIGHT * SCALE,
    0,
  )
  let renderer = @sdl.sdl_CreateRenderer(window, @sdl.SDL_SOFTWARE_RENDERER)

  let texture = @sdl.sdl_CreateTexture(
    renderer,
    @sdl.SDL_PIXELFORMAT_ABGR8888,
    @sdl.SDL_TEXTUREACCESS_STREAMING,
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
  )
  @sdl.sdl_SetTextureScaleMode(texture, @sdl.SDL_SCALEMODE_NEAREST) |> ignore

  let event = @sdl.new_sdl_event()

  Lcd::{ renderer, _window: window, texture, event }
}

///|
fn Lcd::draw(self : Self, pixels : FixedArray[UInt]) -> Bool {
  while @sdl.sdl_PollEvent(self.event) {
    match self.event.get_type() {
      @sdl.SDL_EVENT_QUIT | @sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => return true
      _ => ()
    }
  }

  let src_rect = @sdl.SDL_FRect::{
    x: 0.0,
    y: 0.0,
    w: Float::from_int(SCREEN_WIDTH),
    h: Float::from_int(SCREEN_HEIGHT),
  }
  let dst_rect = @sdl.SDL_FRect::{
    x: 0.0,
    y: 0.0,
    w: Float::from_int(SCREEN_WIDTH * SCALE),
    h: Float::from_int(SCREEN_HEIGHT * SCALE),
  }

  @sdl.sdl_UpdateTexture(
    self.texture,
    @sdl.SDL_Rect::{ x: 0, y: 0, w: SCREEN_WIDTH, h: SCREEN_HEIGHT },
    as_void_ptr(pixels),
    SCREEN_WIDTH * 4,
  )
  |> ignore
  @sdl.sdl_RenderClear(self.renderer) |> ignore
  @sdl.sdl_RenderTexture(self.renderer, self.texture, src_rect, dst_rect)
  |> ignore
  @sdl.sdl_RenderPresent(self.renderer) |> ignore

  false
}
