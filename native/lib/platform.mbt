///|
const SDL_INIT_AUDIO : UInt = 0x00000010

///|
const SDL_INIT_VIDEO : UInt = 0x00000020

///|
extern "C" fn free_sdl_event(event : @sdl.SDL_Event) -> Unit = "lunaboy_free_sdl_event"

///|
extern "C" fn is_null_texture(texture : @sdl.SDL_Texture) -> Bool = "lunaboy_texture_is_null"

///|
priv struct Platform {
  event : @sdl.SDL_Event
  video : Video
  input : Input
  audio : Audio
}

///|
fn Platform::new() -> Self {
  if !@sdl.sdl_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) {
    panic()
  }

  let event = @sdl.new_sdl_event()
  if event.is_null() {
    panic()
  }
  let window = @sdl.sdl_CreateWindow(
    "Luna Boy",
    SCREEN_WIDTH * SCALE,
    SCREEN_HEIGHT * SCALE,
    0,
  )
  if window.is_null() {
    panic()
  }
  let renderer = @sdl.sdl_CreateRenderer(window, @sdl.SDL_SOFTWARE_RENDERER)
  if renderer.is_null() {
    panic()
  }
  let texture = @sdl.sdl_CreateTexture(
    renderer,
    @sdl.SDL_PIXELFORMAT_ABGR8888,
    @sdl.SDL_TEXTUREACCESS_STREAMING,
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
  )
  if is_null_texture(texture) {
    panic()
  }

  if !@sdl.sdl_SetTextureScaleMode(texture, @sdl.SDL_SCALEMODE_NEAREST) {
    panic()
  }

  {
    event,
    video: Video::new(window, renderer, texture),
    input: Input::new(),
    audio: Audio::new(),
  }
}

///|
fn Platform::draw_lcd(self : Self, pixels : FixedArray[UInt]) -> Unit {
  self.video.draw(pixels)
}

///|
fn Platform::queue_audio(self : Self, samples : FixedArray[Float]) -> Unit {
  self.audio.queue(samples)
}

///|
fn Platform::poll_quit(self : Self) -> Bool {
  while @sdl.sdl_PollEvent(self.event) {
    match self.event.get_type() {
      @sdl.SDL_EVENT_QUIT | @sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => return true
      _ => ()
    }
  }
  false
}

///|
fn Platform::update_input(self : Self) -> Unit {
  self.input.update()
}

///|
fn Platform::direction_pressed(self : Self) -> @core.U8 {
  self.input.direction_mask()
}

///|
fn Platform::action_pressed(self : Self) -> @core.U8 {
  self.input.action_mask()
}

///|
fn Platform::clear(self : Self) -> Unit {
  self.audio.clear()
  self.video.clear()
  free_sdl_event(self.event)
  @sdl.sdl_Quit()
}
