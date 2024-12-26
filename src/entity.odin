#+vet unused shadowing using-stmt style semicolon
package main

import rl "vendor:raylib"

Entity_Kind :: enum {
	squire,
	knight,
	ranger,
	swordsman,
	king,
	bomber,
	bomb,
}

Piece_Color :: enum {
	black,
	white,
}

Entity :: struct {
	id:                  int,
	kind:                Entity_Kind,
	color:               Piece_Color,
	position:            IVec2,
	position_prev:       IVec2,
	position_draw:       FVec2,
	capturing:           bool,
	exhausted_for_turns: int,
}

Texture_Color_Agnostic :: struct {
	black: rl.Texture2D,
	white: rl.Texture2D,
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
	case .squire:
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
	case .ranger:
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
	case .swordsman:
		world_try_move_entity(world, entity, entity.position + dir_y)
	case .bomber:
		for world_try_move_entity(world, entity, entity.position + dir_y) {}
		world_add_entity(
			world,
			Entity {
				kind = .bomb,
				color = entity.color,
				position = entity.position,
				position_prev = entity.position,
				position_draw = f_vec_2(entity.position),
			},
		)
		world_remove_entity(world, entity.id)
	case .bomb:
		entity_ids := world_get_entity_ids(world)
		defer delete(entity_ids)
		entity_position := entity.position
		for id in entity_ids {
			other_entity := world_get_entity(world, id).(^Entity) or_continue
			distance_vec := entity_position - other_entity.position
			if abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1 {
				world_remove_entity(world, other_entity.id)

			}
		}
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
		0.1,
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
	texture := entity_get_texture(entity)
	surface_position := camera_world_to_surface(
		&graphics.camera,
		entity.position_draw,
	)
	rl.DrawTextureEx(texture, surface_position, 0, 1.0, rl.WHITE)
	if entity.capturing {
		texture_capturing := graphics.sprites[Sprite_Id.icon_capturing]
		rl.DrawTextureEx(texture_capturing, surface_position, 0, 1.0, rl.WHITE)
	}
	if entity.exhausted_for_turns > 0 {
		texture_exhausted := graphics.sprites[Sprite_Id.icon_exhausted]
		rl.DrawTextureEx(texture_exhausted, surface_position, 0, 1.0, rl.WHITE)
	}
}

entity_get_texture :: proc(entity: ^Entity) -> rl.Texture2D {
	texture := entity_get_texture_color_agnostic(entity.kind)
	if entity.color == Piece_Color.black {
		return texture.black
	} else {
		return texture.white
	}
}

entity_get_texture_color_agnostic :: proc(
	kind: Entity_Kind,
) -> Texture_Color_Agnostic {
	// is_moving :=
	// 	entity.position_draw.x - math.floor(entity.position_draw.x) != 0 ||
	// 	entity.position_draw.y - math.floor(entity.position_draw.y) != 0
	ctx := get_context()
	return ctx.graphics.sprites_pieces[kind]
}
