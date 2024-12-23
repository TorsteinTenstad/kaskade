#+vet unused shadowing using-stmt style semicolon
package main

import rl "vendor:raylib"

Action_Id :: enum {
	pawn,
	knight,
	bishop,
	rook,
	queen,
	king,
}

entity_try_move_to :: proc(
	world: ^World,
	entity: ^Entity,
	new_pos: IVec2,
) -> bool {
	other_entity, occupied := world_get_entity(world, new_pos).(^Entity)
	if occupied {
		if entity.capturing {
			world_remove_entity(world, other_entity)
			log_magenta(entity.id, "captured", other_entity.id)
			entity.position = new_pos
			return true
		} else {
			return false
		}
	} else {
		entity.position = new_pos
		return true
	}
}

entity_run_action :: proc(world: ^World, entity: ^Entity) {
	switch entity.action_id {
	case .pawn:
		entity_try_move_to(world, entity, entity.position + IVec2{0, -1})
	case .knight:
		entity_try_move_to(world, entity, entity.position + IVec2{0, -1})
		for !world_is_empty(world, entity.position + IVec2{0, -1}) {
			if entity_try_move_to(
				world,
				entity,
				entity.position + IVec2{1, -1},
			) {continue}

			if entity_try_move_to(
				world,
				entity,
				entity.position + IVec2{-1, -1},
			) {continue}

			break
		}
	case .bishop:
		entity_try_move_to(world, entity, entity.position + IVec2{0, -1})
	case .rook:
		for x in (entity.position.x + 1) ..< BOARD_WIDTH {
			if !world_is_empty(world, IVec2{x, entity.position.y}) {
				if entity_try_move_to(
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
				if (entity_try_move_to(
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
		entity_try_move_to(world, entity, entity.position + IVec2{0, -1})
	}
}

Entity :: struct {
	id:            int,
	action_id:     Action_Id,
	position:      IVec2,
	draw_position: FVec2,
	sprite_id:     Sprite_Id,
	capturing:     bool,
}

entity_step :: proc(ctx: ^Client_Context, entity: ^Entity) {
	// ctx := get_context()
	// assert(entity.id == ctx.game_state.)
	assert(entity.id == ctx.active_entity_id)

	entity.draw_position = move_towards(
		entity.draw_position,
		f_vec_2(entity.position),
		0.25,
	)

	if entity.draw_position == f_vec_2(entity.position) {
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
	texture := graphics.sprites[entity.sprite_id]
	surface_position := camera_world_to_surface(
		&graphics.camera,
		entity.draw_position,
	)
	rl.DrawTextureEx(texture, surface_position - {1, 0}, 0, 1.0, rl.BLACK)
	rl.DrawTextureEx(texture, surface_position, 0, 1.0, rl.WHITE)
}
