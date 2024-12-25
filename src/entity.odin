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

entity_direction :: proc(color: Piece_Color) -> int {
	if color == .black {
		return 1
	}
	return -1
}

entity_run_action :: proc(world: ^World, entity: ^Entity) {
	entity_dir := entity_direction(entity.color)

	switch entity.kind {
	case .pawn:
		world_try_move_entity(
			world,
			entity,
			entity.position + IVec2{0, entity_dir},
		)
	case .knight:
		world_try_move_entity(
			world,
			entity,
			entity.position + IVec2{0, entity_dir},
		)
		for !world_is_empty(world, entity.position + IVec2{0, entity_dir}) {
			if world_try_move_entity(
				world,
				entity,
				entity.position + IVec2{1, entity_dir},
			) {continue}

			if world_try_move_entity(
				world,
				entity,
				entity.position + IVec2{-1, entity_dir},
			) {continue}

			break
		}
	case .bishop:
		world_try_move_entity(
			world,
			entity,
			entity.position + IVec2{0, entity_dir},
		)
	case .rook:
		for x in (entity.position.x + 1) ..< BOARD_WIDTH {
			if !world_is_empty(world, IVec2{x, entity.position.y}) {
				if world_try_move_entity(
					world,
					entity,
					IVec2{x, entity.position.y},
				) {
					return
				}

			}
		}
		for x in 0 ..< entity.position.x {
			x_reverse := entity.position.x - 1 - x
			if !world_is_empty(world, IVec2{x_reverse, entity.position.y}) {
				if (world_try_move_entity(
						   world,
						   entity,
						   IVec2{x_reverse, entity.position.y},
					   )) {
					return
				}
			}
		}
	case .queen:
	case .king:
		world_try_move_entity(
			world,
			entity,
			entity.position + IVec2{0, entity_dir},
		)
	}
}

entity_step :: proc(ctx: ^Client_Context, entity: ^Entity) {
	assert(entity.id == ctx.active_entity_id)

	entity.position_draw = move_towards(
		entity.position_draw,
		f_vec_2(entity.position),
		0.25,
	)

	if entity.position_draw == f_vec_2(entity.position) {
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
	rl.DrawTextureEx(texture, surface_position - {1, 0}, 0, 1.0, rl.BLACK)
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
