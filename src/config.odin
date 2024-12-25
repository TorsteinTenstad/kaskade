#+vet unused shadowing using-stmt style semicolon
package main

import "core:net"

DEV :: true
DESKTOP :: false

LOAD_SAVE :: false

ASSETS_PATH :: "./assets/"

SURFACE_WIDTH :: 480
SURFACE_HEIGHT :: 270
CAMERA_SPEED :: 0.06

BOARD_WIDTH :: 8
BOARD_HEIGHT :: 8
SPAWN_ZONE_DEPTH :: 2
CHUNK_RENDER_DISTANCE_X :: 2
CHUNK_RENDER_DISTANCE_Y :: 2

GRID_SIZE :: 16
ONE_PIXEL :: (1.0 / f32(GRID_SIZE))

CARD_WIDTH :: 120.0
CARD_HEIGHT :: 200.0
CARDS_MAX :: 6
MANA_MAX :: 5

FONT_DEFAULT :: Font_Id.lilita_one_regular

SERVER_PORT_EVENT :: 16143
SERVER_PORT_STATE :: 16144
SERVER_ADDR :: net.IP4_Address{192, 168, 1, 109}
