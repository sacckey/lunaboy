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
