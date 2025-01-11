#+vet unused shadowing using-stmt style semicolon
package main

import "core:strings"
import rl "vendor:raylib"

Graphics :: struct {
	sprite_sheet: rl.Texture2D,
	fonts:        map[Font_Id]rl.Font,
	surface:      rl.RenderTexture2D,
	camera:       Camera,
	gui_scale:    f32,
}

Sprite_Id :: enum {
	squire,
	knight,
	ranger,
	swordsman,
	king,
	bomber,
	bomb,
	poisonous_bush,
	guard,
	armory,
	market,
	university,
	library,
	icon_capturing,
	icon_haste,
	icon_exhausted,
	adrenaline,
	halt,
	give_arms,
}

_sprite_sheet_positions: [Sprite_Id]IVec2 = {
	.squire         = {cast(int)Sprite_Id.squire, 0},
	.knight         = {cast(int)Sprite_Id.knight, 0},
	.ranger         = {cast(int)Sprite_Id.ranger, 0},
	.swordsman      = {cast(int)Sprite_Id.swordsman, 0},
	.king           = {cast(int)Sprite_Id.king, 0},
	.bomber         = {cast(int)Sprite_Id.bomber, 0},
	.bomb           = {cast(int)Sprite_Id.bomb, 0},
	.poisonous_bush = {cast(int)Sprite_Id.poisonous_bush, 0},
	.guard          = {cast(int)Sprite_Id.guard, 0},
	.armory         = {cast(int)Sprite_Id.armory, 0},
	.market         = {cast(int)Sprite_Id.market, 0},
	.university     = {cast(int)Sprite_Id.university, 0},
	.library        = {cast(int)Sprite_Id.library, 0},
	.adrenaline     = {0, 2},
	.give_arms      = {1, 2},
	.halt           = {2, 2},
	.icon_capturing = {0, 3},
	.icon_exhausted = {1, 3},
	.icon_haste     = {2, 3},
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

	path_sprite_sheet := strings.concatenate(
		{ASSETS_PATH, "sprites/spritesheet.png"},
	)
	ctx.graphics.sprite_sheet = rl.LoadTexture(cstr(path_sprite_sheet))
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

sprite_draw_from_sprite_sheet :: proc(
	sprite_pos: IVec2,
	position: FVec2,
	scale: f32,
) {
	ctx := get_context()
	source: rl.Rectangle = {
		x      = GRID_SIZE * f32(sprite_pos.x),
		y      = GRID_SIZE * f32(sprite_pos.y),
		width  = GRID_SIZE,
		height = GRID_SIZE,
	}
	dest: rl.Rectangle = {
		x      = f32(position.x),
		y      = f32(position.y),
		width  = GRID_SIZE * scale,
		height = GRID_SIZE * scale,
	}
	rl.DrawTexturePro(
		ctx.graphics.sprite_sheet,
		source,
		dest,
		{0, 0},
		0,
		rl.WHITE,
	)
}

sprite_draw_entity :: proc(
	kind: Entity_Kind,
	color: Piece_Color,
	position: FVec2,
	scale: f32,
) {
	sprite_id := _entity_sprite_ids[kind]
	sprite_draw(sprite_id, position, scale, {0, cast(int)color})
}

sprite_draw :: proc(
	sprite_id: Sprite_Id,
	position: FVec2,
	scale: f32,
	offset: IVec2 = {0, 0},
) {
	sprite_pos := _sprite_sheet_positions[sprite_id]
	sprite_draw_from_sprite_sheet(sprite_pos + offset, position, scale)
}
