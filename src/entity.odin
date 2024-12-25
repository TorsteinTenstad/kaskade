#+vet unused shadowing using-stmt style semicolon
package main

import rl "vendor:raylib"

Entity_Kind :: enum {
	pawn,
	knight,
	bishop,
	rook,
	queen,
	king,
}

Piece_Color :: enum {
	black,
	white,
}

Entity :: struct {
	id:            int,
	kind:          Entity_Kind,
	color:         Piece_Color,
	position:      IVec2,
	position_prev: IVec2,
	position_draw: FVec2,
	capturing:     bool,
}

entity_direction_x :: proc(color: Piece_Color) -> IVec2 {
	if color == .black {
		return IVec2{-1, 0}
	}
	return IVec2{1, 0}
}
entity_direction_y :: proc(color: Piece_Color) -> IVec2 {
	if color == .black {
		return IVec2{0, 1}
	}
	return IVec2{0, -1}
}

entity_run_action :: proc(world: ^World, entity: ^Entity) {
	dir_x := entity_direction_x(entity.color)
	dir_y := entity_direction_y(entity.color)

	switch entity.kind {
	case .pawn:
		world_try_move_entity(world, entity, entity.position + dir_y)
	case .knight:
		position_prev := entity.position
		world_try_move_entity(world, entity, entity.position + dir_y)
		for !world_is_empty(world, entity.position + dir_y) {
			if world_try_move_entity(
				world,
				entity,
				entity.position + dir_y + dir_x,
			) {continue}

			if world_try_move_entity(
				world,
				entity,
				entity.position + dir_y - dir_x,
			) {continue}

			break
		}
		if entity.position != position_prev {
			entity.position_prev = position_prev
		}
	case .bishop:
		directions: []IVec2 = {
			dir_x + dir_y,
			-dir_x + dir_y,
			dir_x - dir_y,
			-dir_x - dir_y,
		}

		for direction in directions {
			for i in 1 ..< max(BOARD_WIDTH, BOARD_HEIGHT) {
				position := entity.position + direction * i
				if !world_is_empty(world, position) {
					if world_try_move_entity(world, entity, position) {
						return
					} else {
						break
					}
				}
			}
		}
	case .rook:
		world_try_move_entity(world, entity, entity.position + dir_y)
	case .queen:
	case .king:
		world_try_move_entity(world, entity, entity.position + dir_y)
	}
}

entity_step :: proc(ctx: ^Client_Context, entity: ^Entity) {
	assert(entity.id == ctx.active_entity_id)

	position_draw_prev := entity.position_draw

	entity.position_draw = move_towards(
		entity.position_draw,
		f_vec_2(entity.position),
		0.25,
	)

	if entity.position_draw == f_vec_2(entity.position) {
		if position_draw_prev != f_vec_2(entity.position) {
			audio_play(&ctx.audio, Audio_Id.move)
		}
		select_next_entity(ctx)
	}
}

select_next_entity :: proc(ctx: ^Client_Context) {
	index := -1
	for entity, i in ctx.game_state.world.entities {
		if entity.id == ctx.active_entity_id {
			index = (i + 1) % len(ctx.game_state.world.entities)
			break
		}
	}
	if index != -1 {
		entity := &ctx.game_state.world.entities[index]
		ctx.active_entity_id = entity.id
	}
}

entity_draw :: proc(entity: ^Entity) {
	graphics := &get_context().graphics
	sprite_id := entity_get_sprite_id(entity)
	texture := graphics.sprites[sprite_id]
	surface_position := camera_world_to_surface(
		&graphics.camera,
		entity.position_draw,
	)
	if entity.capturing {
		texture_capturing := graphics.sprites[Sprite_Id.icon_capturing]
		rl.DrawTextureEx(texture_capturing, surface_position, 0, 1.0, rl.WHITE)
	}
	rl.DrawTextureEx(texture, surface_position, 0, 1.0, rl.WHITE)
}

entity_get_sprite_id :: proc(entity: ^Entity) -> Sprite_Id {
	is_white := entity.color == Piece_Color.white

	switch entity.kind {
	case .pawn:
		return is_white ? Sprite_Id.pawn_w : Sprite_Id.pawn_b
	case .knight:
		return is_white ? Sprite_Id.knight_w : Sprite_Id.knight_b
	case .bishop:
		return is_white ? Sprite_Id.bishop_w : Sprite_Id.bishop_b
	case .rook:
		return is_white ? Sprite_Id.rook_w : Sprite_Id.rook_b
	case .king:
		return is_white ? Sprite_Id.king_w : Sprite_Id.king_b
	case .queen:
		return is_white ? Sprite_Id.queen_w : Sprite_Id.queen_b
	}
	assert(false, "non-exhaustive")
	return Sprite_Id.player
}
