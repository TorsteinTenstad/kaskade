#+vet unused shadowing using-stmt style semicolon
package main

import rl "vendor:raylib"

Entity_Kind :: enum {
	player,
	enemy,
}

Entity :: struct {
	kind:          Entity_Kind,
	id:            int,
	chunk:         IVec2,
	position:      IVec2,
	draw_position: FVec2,
	sprite_id:     Sprite_Id,
	health:        int,
	done:          bool,
}

entity_step :: proc(entity: ^Entity) {
	game_state := get_game_state()
	assert(entity.id == game_state.current_entity_id)

	entity.draw_position = move_towards(
		entity.draw_position,
		f_vec_2(entity.position),
		0.25,
	)
}

entity_draw :: proc(entity: ^Entity) {
	graphics := &get_game_state().graphics
	texture := graphics.sprites[entity.sprite_id]
	surface_position := camera_world_to_surface(
		&graphics.camera,
		entity.draw_position,
	)
	rl.DrawTextureEx(texture, surface_position - {1, 0}, 0, 1.0, rl.BLACK)
	rl.DrawTextureEx(texture, surface_position, 0, 1.0, rl.WHITE)
}

entity_draw_gui :: proc(entity: ^Entity) {
	graphics := &get_game_state().graphics
	gui_position := camera_world_to_gui(
		&graphics.camera,
		entity.draw_position + {0, -0.2},
	)

	draw_text(format("HP: ", entity.health), gui_position)
}
