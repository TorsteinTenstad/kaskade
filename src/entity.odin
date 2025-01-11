#+vet unused shadowing using-stmt style semicolon
package main

Entity_Kind :: enum {
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
	spawn_aura:          Maybe(Area),
	immune_aura:         Maybe(Area),
	capturing:           bool,
	poisonous:           bool,
	exhausted_for_turns: int,
}

_entity_sprite_ids: map[Entity_Kind]Sprite_Id = {
	.squire         = .squire,
	.knight         = .knight,
	.ranger         = .ranger,
	.swordsman      = .swordsman,
	.king           = .king,
	.bomber         = .bomber,
	.bomb           = .bomb,
	.poisonous_bush = .poisonous_bush,
	.guard          = .guard,
	.armory         = .armory,
	.market         = .market,
	.university     = .university,
	.library        = .library,
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

entity_run_action :: proc(game_state: ^Server_Game_State, entity: ^Entity) {
	dir_x := entity_direction_x(entity.color)
	dir_y := entity_direction_y(entity.color)

	switch entity.kind {
	case .squire:
		world_try_move_entity(
			&game_state.world,
			entity,
			entity.position + dir_y,
		)
	case .knight:
		position_prev := entity.position
		world_try_move_entity(
			&game_state.world,
			entity,
			entity.position + dir_y,
		)
		for !world_is_empty(&game_state.world, entity.position + dir_y) {
			if world_try_move_entity(
				&game_state.world,
				entity,
				entity.position + dir_y + dir_x,
			) {continue}

			if world_try_move_entity(
				&game_state.world,
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
				if !world_is_empty(&game_state.world, position) {
					if world_try_move_entity(
						&game_state.world,
						entity,
						position,
					) {
						return
					} else {
						break
					}
				}
			}
		}
	case .swordsman:
		world_try_move_entity(
			&game_state.world,
			entity,
			entity.position + dir_y,
		)
	case .bomber:
		for world_try_move_entity(
			    &game_state.world,
			    entity,
			    entity.position + dir_y,
		    ) {}
		world_add_entity(
			&game_state.world,
			Entity {
				kind = .bomb,
				color = entity.color,
				position = entity.position,
				position_prev = entity.position,
				position_draw = f_vec_2(entity.position),
			},
		)
		world_remove_entity(&game_state.world, entity.id)
	case .bomb:
		entity_ids := world_get_entity_ids(&game_state.world)
		defer delete(entity_ids)
		entity_position := entity.position
		for id in entity_ids {
			other_entity := world_get_entity(
				&game_state.world,
				id,
			).(^Entity) or_continue
			distance_vec := entity_position - other_entity.position
			if abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1 {
				world_remove_entity(&game_state.world, other_entity.id)

			}
		}
	case .king:
		world_try_move_entity(
			&game_state.world,
			entity,
			entity.position + dir_y,
		)
	case .poisonous_bush:
	case .guard:
		world_try_move_entity(
			&game_state.world,
			entity,
			entity.position + dir_y,
		)
	case .armory:
		for &other_entity in &game_state.world.entities {
			if other_entity.color == entity.color {
				other_entity.capturing = true
			}
		}
	case .market:
		switch entity.color {
		case .black:
			hand_draw_from_deck(&game_state.black.hand, &game_state.black.deck)
		case .white:
			hand_draw_from_deck(&game_state.white.hand, &game_state.white.deck)
		}
	case .university:
		switch entity.color {
		case .black:
			append(&game_state.black.hand.cards, hand_generate_handle(.squire))
		case .white:
			append(&game_state.white.hand.cards, hand_generate_handle(.squire))
		}
	case .library:
	}
}

entity_draw :: proc(entity: ^Entity, position_draw: FVec2) {
	graphics := &get_context().graphics
	surface_position := camera_world_to_surface(
		&graphics.camera,
		position_draw,
	)
	sprite_draw_entity(entity.kind, entity.color, surface_position, 1)

	if entity.capturing {
		sprite_draw(.icon_capturing, surface_position, 1)
	}
	if entity.exhausted_for_turns > 0 {
		sprite_draw(.icon_exhausted, surface_position, 1)
	}
}
