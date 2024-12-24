#+vet unused shadowing using-stmt style semicolon
package main

World :: struct {
	entities:             [dynamic]Entity,
	next_world_object_id: int,
}

player_in_spawn_zone :: proc(player: Piece_Color, pos: IVec2) -> bool {
	switch player {
	case .white:
		return(
			0 <= pos.x &&
			pos.x < BOARD_WIDTH &&
			(BOARD_HEIGHT - SPAWN_ZONE_DEPTH) <= pos.y &&
			pos.y < BOARD_WIDTH \
		)
	case .black:
		return(
			0 <= pos.x &&
			pos.x < BOARD_WIDTH &&
			0 <= pos.y &&
			pos.y < SPAWN_ZONE_DEPTH \
		)
	}
	assert(false, "non-exhaustive")
	return false
}

player_close_to_king :: proc(
	world: ^World,
	player: Piece_Color,
	pos: IVec2,
) -> bool {
	for &entity in world.entities {
		if entity.kind == .king && entity.color == player {
			distance_vec := pos - entity.position
			return abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1
		}
	}
	return false
}

player_try_place_entity :: proc(world: ^World, entity: Entity) -> Maybe(int) {
	if world_is_empty(world, entity.position) &&
	   (player_in_spawn_zone(entity.color, entity.position) ||
			   player_close_to_king(world, entity.color, entity.position)) {
		return world_add_entity(world, entity)
	}
	return nil
}

world_add_entity :: proc(world: ^World, entity: Entity) -> int {
	entity := entity
	entity.draw_position = f_vec_2(entity.position)
	entity.id = world.next_world_object_id
	world.next_world_object_id += 1
	append(&world.entities, entity)
	return entity.id
}

world_get_entity_ids :: proc(
	world: ^World,
	allocator := context.allocator,
) -> []int {
	size := len(world.entities)
	ids := make([]int, size, allocator)
	for &entity, i in world.entities {
		ids[i] = entity.id
	}
	return ids
}

_world_remove_entity_from_struct :: proc(
	world: ^World,
	entity: ^Entity,
) -> bool {
	return world_remove_entity(world, entity.id)
}

_world_remove_entity_from_id :: proc(world: ^World, entity_id: int) -> bool {
	index, found := _world_get_entity_index(world, entity_id).(int)
	if !found do return false
	unordered_remove(&world.entities, index)
	return true
}

world_remove_entity :: proc {
	_world_remove_entity_from_struct,
	_world_remove_entity_from_id,
}

@(private = "file")
_world_get_entity_from_position :: proc(
	world: ^World,
	world_position: IVec2,
) -> Maybe(^Entity) {
	for &entity in world.entities {
		if entity.position == world_position {
			return &entity
		}
	}
	return nil
}

@(private = "file")
_world_get_entity_from_id :: proc(
	world: ^World,
	entity_id: int,
) -> Maybe(^Entity) {
	index, found := _world_get_entity_index(world, entity_id).(int)
	if !found {
		return nil
	} else {
		return &world.entities[index]
	}
}

world_get_entity :: proc {
	_world_get_entity_from_position,
	_world_get_entity_from_id,
}

// Return its index in world.entities, not its id.
// Returns -1 if it is not found.
@(private = "file")
_world_get_entity_index :: proc(world: ^World, entity_id: int) -> Maybe(int) {
	for entity, i in world.entities {
		if entity.id == entity_id {
			return i
		}
	}
	return nil
}

world_is_empty :: proc(world: ^World, world_position: IVec2) -> bool {
	_, not_empty := world_get_entity(world, world_position).(^Entity)
	return !not_empty
}
