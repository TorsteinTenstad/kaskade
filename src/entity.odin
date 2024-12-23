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

entity_run_action :: proc(world: ^World, entity: ^Entity) {
	entity.draw_position = f_vec_2(entity.position)

	switch entity.action_id {
	case .pawn:
		entity.position.y -= 1
	case .knight:
	case .bishop:
	case .rook:
	case .queen:
	case .king:
	}
}

Entity :: struct {
	id:            int,
	action_id:     Action_Id,
	position:      IVec2,
	draw_position: FVec2,
	sprite_id:     Sprite_Id,
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
