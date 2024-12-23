#+vet unused shadowing using-stmt style semicolon
package main

World :: struct {
	entities:             [dynamic]Entity,
	next_world_object_id: int,
}

world_add_entity :: proc(world: ^World, entity: Entity) -> int {
	entity := entity
	entity.draw_position = f_vec_2(entity.position)
	entity.id = world.next_world_object_id
	world.next_world_object_id += 1
	append(&world.entities, entity)
	return entity.id
}

world_remove_entity :: proc(world: ^World, entity: ^Entity) -> bool {
	index := world_get_entity_index(world, entity.id)
	if index < 0 do return false
	unordered_remove(&world.entities, index)
	return true
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
	index := world_get_entity_index(world, entity_id)
	if index < 0 {
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
world_get_entity_index :: proc(world: ^World, entity_id: int) -> int {
	for entity, i in world.entities {
		if entity.id == entity_id {
			return i
		}
	}
	return -1
}

world_is_empty :: proc(world: ^World, world_position: IVec2) -> bool {
	_, not_empty := world_get_entity(world, world_position).(^Entity)
	return !not_empty
}
