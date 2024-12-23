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
	pawn_b,
	knight_b,
	bishop_b,
	rook_b,
	queen_b,
	king_b,
	pawn_w,
	knight_w,
	bishop_w,
	rook_w,
	queen_w,
	king_w,
}

Sprite_Paths := [Sprite_Id]string {
	.player   = "player.png",
	.skeleton = "skeleton.png",
	.pawn_b   = "black_pawn.png",
	.knight_b = "black_knight.png",
	.bishop_b = "black_bishop.png",
	.rook_b   = "black_rook.png",
	.queen_b  = "black_queen.png",
	.king_b   = "black_king.png",
	.pawn_w   = "white_pawn.png",
	.knight_w = "white_knight.png",
	.bishop_w = "white_bishop.png",
	.rook_w   = "white_rook.png",
	.queen_w  = "white_queen.png",
	.king_w   = "white_king.png",
}

Font_Id :: enum {
	lilita_one_regular,
	nova_square_regular,
}

Font_Paths := [Font_Id]string {
	.lilita_one_regular  = "LilitaOne-Regular.ttf",
	.nova_square_regular = "NovaSquare-Regular.ttf",
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
	ctx.graphics.fonts = _load_fonts()
	rl.GuiSetFont(ctx.graphics.fonts[Font_Id.lilita_one_regular])

	ctx.graphics.surface = rl.LoadRenderTexture(SURFACE_WIDTH, SURFACE_HEIGHT)
	rl.SetTextureFilter(ctx.graphics.surface.texture, rl.TextureFilter.POINT)

	ctx.graphics.camera.view_size = {
		SURFACE_WIDTH / GRID_SIZE,
		SURFACE_HEIGHT / GRID_SIZE,
	}
	ctx.graphics.camera.target_position = {BOARD_WIDTH / 2, BOARD_HEIGHT / 2}
}

@(private = "file")
_load_sprites :: proc() -> map[Sprite_Id]rl.Texture {
	m := make(map[Sprite_Id]rl.Texture)

	for sprite_id in Sprite_Id {
		sprite_path := Sprite_Paths[sprite_id]
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
