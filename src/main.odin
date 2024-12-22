#+vet unused shadowing using-stmt style semicolon
package main

import "core:thread"
import rl "vendor:raylib"

@(private = "file")
_game_state: Game_State
is_server: bool = true

get_game_state :: proc() -> ^Game_State {
	return &_game_state
}


main :: proc() {
	_game_state = game_state_create()
	graphics_create(&_game_state)


	thread.create_and_start(server_start)

	// Main loop
	for !rl.WindowShouldClose() {

		if is_server {
			_server_step(&_game_state)
		}

		_main_step(&_game_state)
		_main_draw(&_game_state)
	}

	rl.CloseWindow()
}

@(private = "file")
_server_step :: proc(game_state: ^Game_State) {

}

@(private = "file")
_main_step :: proc(game_state: ^Game_State) {

	// Camera
	camera := &game_state.graphics.camera
	camera_step(camera, &game_state.world)

	// Hand
	hand_step(game_state)
}

COLOR_BACKGROUND_DARK: rl.Color : {21, 18, 20, 255}
COLOR_BACKGROUND_LIGHT: rl.Color : {29, 25, 27, 255}

@(private = "file")
_main_draw :: proc(game_state: ^Game_State) {
	camera := &game_state.graphics.camera
	scale := camera_surface_scale(camera)

	// Draw onto texture
	rl.BeginTextureMode(game_state.graphics.surface)

	{
		// Background
		rl.ClearBackground(COLOR_BACKGROUND_DARK)
		for x in 0 ..< 8 {
			for y in 0 ..< 8 {
				dark, light := COLOR_BACKGROUND_DARK, COLOR_BACKGROUND_LIGHT
				is_light := ((x % 2) + (y % 2)) != 1
				rl.DrawRectangleV(
					camera_world_to_surface(camera, IVec2{x, y}),
					{GRID_SIZE, GRID_SIZE},
					is_light ? light : dark,
				)
			}
		}

		// Card range
		card_index, is_hovering := game_state.hand.hover_index.(int)
		if is_hovering {
			card := &game_state.hand.cards[card_index]
			world_positions := card_get_positions(&card.card)
			for world_position in world_positions {
				surface_position := i32_vec_2(
					camera_world_to_surface(camera, world_position),
				)
				rl.DrawRectangleLines(
					surface_position.x,
					surface_position.y,
					GRID_SIZE + 1,
					GRID_SIZE + 1,
					rl.Color{130, 150, 155, 164},
				)
			}
		}

		// Entities
		for entity_id in game_state.world.world_object_ids {
			entity, _ := world_get_entity(
				&game_state.world,
				entity_id,
			).(^Entity)
			entity_draw(entity)
		}
	}
	rl.EndTextureMode()

	// Draw texture onto screen
	rl.BeginDrawing()

	{
		rl.ClearBackground(rl.BLACK)
		texture := game_state.graphics.surface.texture
		surface_origin := camera_surface_origin(camera)
		// Hack to make camera smooth
		subpixel := FVec2 {
			floor_to_multiple(camera.position.x, scale) - camera.position.x,
			floor_to_multiple(camera.position.y, scale) - camera.position.y,
		}

		rl.DrawTexturePro(
			texture,
			{0.0, 0.0, f32(texture.width), -f32(texture.height)},
			{
				surface_origin.x + subpixel.x,
				surface_origin.y + subpixel.y,
				f32(SURFACE_WIDTH) * scale,
				f32(SURFACE_HEIGHT) * scale,
			},
			{0, 0},
			0.0,
			rl.WHITE,
		)

		draw_text(format(rl.GetFPS()), {16, 16})

		// GUI
		for entity_id in game_state.world.world_object_ids {
			entity, _ := world_get_entity(
				&game_state.world,
				entity_id,
			).(^Entity)
			entity_draw_gui(entity)
		}
		hand_draw_gui(&game_state.hand, camera)
	}
	rl.EndDrawing()
}
