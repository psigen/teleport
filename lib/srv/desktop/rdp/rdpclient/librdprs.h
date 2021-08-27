/*
 * Copyright 2021 Gravitational, Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum CGOPointerButton {
  PointerButtonNone,
  PointerButtonLeft,
  PointerButtonRight,
  PointerButtonMiddle,
} CGOPointerButton;

typedef struct Client Client;

typedef char *CGOError;

typedef struct ClientOrError {
  struct Client *client;
  CGOError err;
} ClientOrError;

typedef struct CGOPointer {
  uint16_t x;
  uint16_t y;
  enum CGOPointerButton button;
  bool down;
} CGOPointer;

typedef struct CGOKey {
  uint16_t code;
  bool down;
} CGOKey;

typedef struct CGOBitmap {
  uint16_t dest_left;
  uint16_t dest_top;
  uint16_t dest_right;
  uint16_t dest_bottom;
  uint8_t *data_ptr;
  uintptr_t data_len;
  uintptr_t data_cap;
} CGOBitmap;

void init(void);

struct ClientOrError connect_rdp(char *go_addr,
                                 char *go_username,
                                 char *go_password,
                                 uint16_t screen_width,
                                 uint16_t screen_height);

CGOError read_rdp_output(struct Client *client_ptr, int64_t client_ref);

CGOError write_rdp_pointer(struct Client *client_ptr, struct CGOPointer pointer);

CGOError write_rdp_keyboard(struct Client *client_ptr, struct CGOKey key);

CGOError close_rdp(struct Client *client_ptr);

void free_rdp(struct Client *client_ptr);

void free_rust_string(char *s);

extern void free_go_string(char *s);

extern CGOError handle_bitmap(int64_t client_ref, struct CGOBitmap b);
