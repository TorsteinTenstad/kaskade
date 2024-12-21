#+vet unused shadowing using-stmt style semicolon
package main

import "core:strings"
import rl "vendor:raylib"

ASSETS_PATH :: "./assets/"

Graphics :: struct {
	sprites: map[Sprite_Id]rl.Texture,
	fonts:   map[Font_Id]rl.Font,
	surface: rl.RenderTexture2D,
	camera:  Camera,
}

Sprite_Id :: enum {
	player,
	skeleton,
}

Sprite_Paths := [Sprite_Id]string {
	.player   = "player.png",
	.skeleton = "skeleton.png",
}

Font_Id :: enum {
	lilita_one_regular,
	nova_square_regular,
}

Font_Paths := [Font_Id]string {
	.lilita_one_regular  = "LilitaOne-Regular.ttf",
	.nova_square_regular = "NovaSquare-Regular.ttf",
}

graphics_create :: proc(game_state: ^Game_State) {
	when DEV && DESKTOP {
		window_width :: 1920
		window_height :: 2070
	} else when DEV {
		window_width :: 800
		window_height :: 480
	} else {
		window_width :: 1920
		window_height :: 1080
	}

	rl.InitWindow(window_width, window_height, "Rogue Deck")
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTargetFPS(60)

	when DEV && DESKTOP {
		rl.SetWindowPosition(1920, 32)
	}

	game_state.graphics.sprites = _load_sprites()
	game_state.graphics.fonts = _load_fonts()
	rl.GuiSetFont(game_state.graphics.fonts[Font_Id.lilita_one_regular])

	game_state.graphics.surface = rl.LoadRenderTexture(
		SURFACE_WIDTH,
		SURFACE_HEIGHT,
	)
	rl.SetTextureFilter(
		game_state.graphics.surface.texture,
		rl.TextureFilter.POINT,
	)

	game_state.graphics.camera.view_size = {
		SURFACE_WIDTH / GRID_SIZE,
		SURFACE_HEIGHT / GRID_SIZE,
	}
	game_state.graphics.camera.target_position = {4, 4}
}

@(private = "file")
_load_sprites :: proc() -> map[Sprite_Id]rl.Texture {
	m := make(map[Sprite_Id]rl.Texture)

	for sprite_id in Sprite_Id {
		sprite_path := Sprite_Paths[sprite_id]
		full_path := strings.concatenate({ASSETS_PATH, sprite_path})
		m[sprite_id] = rl.LoadTexture(cstr(full_path))
	}
	return m
}

@(private = "file")
_load_fonts :: proc() -> map[Font_Id]rl.Font {
	m := make(map[Font_Id]rl.Font)

	for font_id in Font_Id {
		font_path := Font_Paths[font_id]
		full_path := strings.concatenate({ASSETS_PATH, font_path})
		m[font_id] = rl.LoadFontEx(cstr(full_path), 128, {}, 0)
		rl.SetTextureFilter(m[font_id].texture, rl.TextureFilter.BILINEAR)
	}
	return m
}
