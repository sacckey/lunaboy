///|
const SDL_INIT_VIDEO : UInt = 0x00000020

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
extern "C" fn read_keys4(a : Int, b : Int, c : Int, d : Int) -> U8 = "lunaboy_read_keys4"

///|
extern "C" fn free_sdl_event(event : @sdl.SDL_Event) -> Unit = "lunaboy_free_sdl_event"

///|
type SDL_Window = @sdl.SDL_Window

///|
type SDL_Renderer = @sdl.SDL_Renderer

///|
type SDL_Texture = @sdl.SDL_Texture

///|
fn[T] as_void_ptr(value : T) -> @sdl.VoidPtr = "%identity"

///|
priv struct Sdl {
  mut initialized : Bool
  mut event : @sdl.SDL_Event?
  mut direction_pressed : U8
  mut action_pressed : U8
}

///|
fn Sdl::new() -> Self {
  let initialized = @sdl.sdl_Init(SDL_INIT_VIDEO)
  let event = if initialized {
    Some(@sdl.new_sdl_event()).filter(event => !event.is_null())
  } else {
    None
  }

  { initialized, event, direction_pressed: 0, action_pressed: 0 }
}

///|
fn sdl_create_window(
  title : String,
  width : Int,
  height : Int,
  scale : Int,
) -> SDL_Window {
  @sdl.sdl_CreateWindow(title, width * scale, height * scale, 0)
}

///|
fn sdl_create_renderer(window : SDL_Window) -> SDL_Renderer {
  @sdl.sdl_CreateRenderer(window, @sdl.SDL_SOFTWARE_RENDERER)
}

///|
fn sdl_create_texture(
  renderer : SDL_Renderer,
  width : Int,
  height : Int,
) -> SDL_Texture {
  let texture = @sdl.sdl_CreateTexture(
    renderer,
    @sdl.SDL_PIXELFORMAT_ABGR8888,
    @sdl.SDL_TEXTUREACCESS_STREAMING,
    width,
    height,
  )
  @sdl.sdl_SetTextureScaleMode(texture, @sdl.SDL_SCALEMODE_NEAREST) |> ignore
  texture
}

///|
fn sdl_draw_lcd(
  renderer : SDL_Renderer,
  texture : SDL_Texture,
  pixels : FixedArray[UInt],
  width : Int,
  height : Int,
  scale : Int,
) -> Unit {
  let src_rect = @sdl.SDL_FRect::{
    x: 0.0,
    y: 0.0,
    w: Float::from_int(width),
    h: Float::from_int(height),
  }
  let dst_rect = @sdl.SDL_FRect::{
    x: 0.0,
    y: 0.0,
    w: Float::from_int(width * scale),
    h: Float::from_int(height * scale),
  }

  @sdl.sdl_UpdateTexture(
    texture,
    @sdl.SDL_Rect::{ x: 0, y: 0, w: width, h: height },
    as_void_ptr(pixels),
    width * 4,
  )
  |> ignore
  @sdl.sdl_RenderClear(renderer) |> ignore
  @sdl.sdl_RenderTexture(renderer, texture, src_rect, dst_rect) |> ignore
  @sdl.sdl_RenderPresent(renderer) |> ignore
}

///|
fn sdl_destroy_texture(texture : SDL_Texture) -> Unit {
  @sdl.sdl_DestroyTexture(texture)
}

///|
fn sdl_destroy_renderer(renderer : SDL_Renderer) -> Unit {
  @sdl.sdl_DestroyRenderer(renderer)
}

///|
fn sdl_destroy_window(window : SDL_Window) -> Unit {
  @sdl.sdl_DestroyWindow(window)
}

///|
fn Sdl::poll_quit(self : Self) -> Bool {
  if self.event is Some(event) {
    while @sdl.sdl_PollEvent(event) {
      match event.get_type() {
        @sdl.SDL_EVENT_QUIT | @sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED =>
          return true
        _ => ()
      }
    }
  }
  false
}

///|
fn Sdl::update_keyboard(self : Self) -> Unit {
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
fn Sdl::direction_pressed(self : Self) -> U8 {
  self.direction_pressed
}

///|
fn Sdl::action_pressed(self : Self) -> U8 {
  self.action_pressed
}

///|
fn Sdl::clear(self : Self) -> Unit {
  if self.event is Some(event) {
    free_sdl_event(event)
    self.event = None
  }
  if self.initialized {
    @sdl.sdl_Quit()
    self.initialized = false
  }
}
