#include <SDL3/SDL.h>
#include <stdint.h>
#include <stdlib.h>

uint8_t lunaboy_read_keys4(int a, int b, int c, int d) {
  int numkeys = 0;
  const bool *state = SDL_GetKeyboardState(&numkeys);
  uint8_t mask = 0;

  if (!state) {
    return 0;
  }

  if (0 <= a && a < numkeys && state[a]) {
    mask |= 0b0001;
  }
  if (0 <= b && b < numkeys && state[b]) {
    mask |= 0b0010;
  }
  if (0 <= c && c < numkeys && state[c]) {
    mask |= 0b0100;
  }
  if (0 <= d && d < numkeys && state[d]) {
    mask |= 0b1000;
  }

  return mask;
}

void lunaboy_free_sdl_event(SDL_Event *event) {
  if (event != NULL) {
    free(event);
  }
}

bool lunaboy_texture_is_null(SDL_Texture *texture) {
  return texture == NULL;
}

bool lunaboy_audio_stream_is_null(SDL_AudioStream *stream) {
  return stream == NULL;
}

static SDL_AudioDeviceID g_audio_device = 0;
static SDL_AudioStream *g_audio_stream = NULL;

bool lunaboy_audio_open(int sample_rate, int channels) {
  if (g_audio_stream != NULL) {
    SDL_DestroyAudioStream(g_audio_stream);
    g_audio_stream = NULL;
  }
  if (g_audio_device != 0) {
    SDL_CloseAudioDevice(g_audio_device);
    g_audio_device = 0;
  }

  SDL_AudioSpec src_spec;
  SDL_zero(src_spec);
  src_spec.format = SDL_AUDIO_F32;
  src_spec.channels = channels;
  src_spec.freq = sample_rate;

  g_audio_device =
      SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &src_spec);
  if (g_audio_device == 0) {
    return false;
  }

  SDL_AudioSpec dst_spec = src_spec;
  int sample_frames = 0;
  if (!SDL_GetAudioDeviceFormat(g_audio_device, &dst_spec, &sample_frames)) {
    dst_spec = src_spec;
  }

  g_audio_stream = SDL_CreateAudioStream(&src_spec, &dst_spec);
  if (g_audio_stream == NULL) {
    SDL_CloseAudioDevice(g_audio_device);
    g_audio_device = 0;
    return false;
  }

  if (!SDL_BindAudioStream(g_audio_device, g_audio_stream)) {
    SDL_DestroyAudioStream(g_audio_stream);
    g_audio_stream = NULL;
    SDL_CloseAudioDevice(g_audio_device);
    g_audio_device = 0;
    return false;
  }

  if (!SDL_ResumeAudioDevice(g_audio_device)) {
    SDL_DestroyAudioStream(g_audio_stream);
    g_audio_stream = NULL;
    SDL_CloseAudioDevice(g_audio_device);
    g_audio_device = 0;
    return false;
  }

  return true;
}

bool lunaboy_audio_queue(const void *ptr, int len_bytes) {
  if (g_audio_stream == NULL) {
    return false;
  }
  return SDL_PutAudioStreamData(g_audio_stream, ptr, len_bytes);
}

int lunaboy_audio_queued_bytes(void) {
  if (g_audio_stream == NULL) {
    return 0;
  }
  return SDL_GetAudioStreamQueued(g_audio_stream);
}

void lunaboy_audio_close(void) {
  if (g_audio_stream != NULL) {
    SDL_DestroyAudioStream(g_audio_stream);
    g_audio_stream = NULL;
  }
  if (g_audio_device != 0) {
    SDL_CloseAudioDevice(g_audio_device);
    g_audio_device = 0;
  }
}
