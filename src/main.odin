#+vet unused shadowing using-stmt style semicolon
package main

import "core:thread"
import rl "vendor:raylib"

@(private = "file")
_client_context: Client_Context
is_server: bool = true

get_context :: proc() -> ^Client_Context {
	return &_client_context
}


main :: proc() {

	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	// Server
	ctx: Server_Context
	server_start(&ctx)

	// Client
	_client_context = client_context_create()
	graphics_create(&_client_context)

	thread.create_and_start_with_data(&_client_context, recv_state_from_server)

	for !rl.WindowShouldClose() {
		_main_step(&_client_context)
		_main_draw(&_client_context)
	}
	rl.CloseWindow()
}

@(private = "file")
_main_step :: proc(ctx: ^Client_Context) {
	// Camera
	camera := &ctx.graphics.camera
	camera_step(camera, &ctx.game_state.world)

	// Hand
	hand_step_player(ctx)
	hand_step(ctx)

	// Input
	if rl.IsKeyPressed(.ENTER) {
		send_package(ctx.socket_event, Client_To_Server{end_turn = End_Turn{}})
	}
}

COLOR_BACKGROUND_DARK: rl.Color : {21, 18, 20, 255}
COLOR_BACKGROUND_LIGHT: rl.Color : {29, 25, 27, 255}

@(private = "file")
_main_draw :: proc(ctx: ^Client_Context) {
	camera := &ctx.graphics.camera
	scale := camera_surface_scale(camera)

	// Draw onto texture
	rl.BeginTextureMode(ctx.graphics.surface)

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
		card_index, is_hovering := ctx.physical_hand.hover_index.(int)
		if is_hovering {
			card := &ctx.physical_hand.cards[card_index]
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
		for &entity in ctx.game_state.world.entities {
			entity_draw(&entity)
		}
	}
	rl.EndTextureMode()

	// Draw texture onto screen
	rl.BeginDrawing()

	{
		rl.ClearBackground(rl.BLACK)
		texture := ctx.graphics.surface.texture
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
		for &entity in ctx.game_state.world.entities {
			entity_draw_gui(&entity)
		}
		hand_draw_gui(&ctx.physical_hand, camera)
	}
	rl.EndDrawing()
}
