#+vet unused shadowing using-stmt style semicolon
package main

import "core:strings"
import rl "vendor:raylib"

Graphics :: struct {
	sprites:        map[Sprite_Id]rl.Texture,
	sprites_pieces: map[Entity_Kind]Texture_Color_Agnostic,
	fonts:          map[Font_Id]rl.Font,
	surface:        rl.RenderTexture2D,
	camera:         Camera,
	gui_scale:      f32,
}

Sprite_Id :: enum {
	icon_capturing,
	icon_haste,
	icon_exhausted,
	adrenaline,
	halt,
	give_arms,
}

_sprite_paths := [Sprite_Id]string {
	.icon_capturing = "sprites/icons/capturing.png",
	.icon_haste     = "sprites/icons/haste.png",
	.icon_exhausted = "sprites/icons/exhausted.png",
	.adrenaline     = "sprites/adrenaline.png",
	.halt           = "sprites/halt.png",
	.give_arms      = "sprites/give_arms.png",
}

Font_Id :: enum {
	lilita_one_regular,
	nova_square_regular,
}

_font_paths := [Font_Id]string {
	.lilita_one_regular  = "fonts/LilitaOne-Regular.ttf",
	.nova_square_regular = "fonts/NovaSquare-Regular.ttf",
}

graphics_create :: proc(ctx: ^Client_Context) {
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

	rl.InitWindow(window_width, window_height, "Kaskade")
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTargetFPS(60)

	when DEV && DESKTOP {
		rl.SetWindowPosition(1920, 32)
	}

	ctx.graphics.sprites = _load_sprites()
	ctx.graphics.sprites_pieces = _load_sprites_pieces()
	ctx.graphics.fonts = _load_fonts()
	rl.GuiSetFont(ctx.graphics.fonts[Font_Id.lilita_one_regular])

	ctx.graphics.surface = rl.LoadRenderTexture(SURFACE_WIDTH, SURFACE_HEIGHT)
	rl.SetTextureFilter(ctx.graphics.surface.texture, rl.TextureFilter.POINT)

	ctx.graphics.camera.view_size = {
		SURFACE_WIDTH / GRID_SIZE,
		SURFACE_HEIGHT / GRID_SIZE,
	}
	ctx.graphics.camera.target_position = {
		BOARD_WIDTH / 2,
		BOARD_HEIGHT / 2 + 0.5,
	}
	ctx.graphics.gui_scale = 1.0
}

@(private = "file")
_load_sprites :: proc() -> map[Sprite_Id]rl.Texture {
	m := make(map[Sprite_Id]rl.Texture)

	for sprite_id in Sprite_Id {
		sprite_path := _sprite_paths[sprite_id]
		full_path := strings.concatenate({ASSETS_PATH, sprite_path})
		texture := rl.LoadTexture(cstr(full_path))
		if texture.id == 0 {
			log_red("Could not find sprite", sprite_path)
		}
		m[sprite_id] = texture
	}
	return m
}

@(private = "file")
_load_sprites_pieces :: proc() -> map[Entity_Kind]Texture_Color_Agnostic {
	m := make(map[Entity_Kind]Texture_Color_Agnostic)

	for sprite_id in Entity_Kind {
		sprites_path := "sprites/pieces/"
		texture: Texture_Color_Agnostic

		path_black := strings.concatenate(
			{ASSETS_PATH, sprites_path, "pink/", format(sprite_id), ".png"},
		)
		texture_black := rl.LoadTexture(cstr(path_black))
		if texture_black.id == 0 {
			log_red("Could not find sprite", path_black)
		} else {
			texture.black = texture_black
		}

		path_white := strings.concatenate(
			{ASSETS_PATH, sprites_path, "green/", format(sprite_id), ".png"},
		)
		texture_white := rl.LoadTexture(cstr(path_white))
		if texture_white.id == 0 {
			log_red("Could not find sprite", path_white)
		} else {
			texture.white = texture_white
		}

		m[sprite_id] = texture
	}
	return m
}

@(private = "file")
_load_fonts :: proc() -> map[Font_Id]rl.Font {
	m := make(map[Font_Id]rl.Font)

	for font_id in Font_Id {
		font_path := _font_paths[font_id]
		full_path := strings.concatenate({ASSETS_PATH, font_path})
		m[font_id] = rl.LoadFontEx(cstr(full_path), 128, {}, 0)
		rl.SetTextureFilter(m[font_id].texture, rl.TextureFilter.BILINEAR)
	}
	return m
}
