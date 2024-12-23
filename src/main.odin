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

	thread.create_and_start(ai_run)

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
	// Update game_state
	game_state_apply_incoming(ctx)

	// Camera
	camera := &ctx.graphics.camera
	camera_step(camera, &ctx.game_state.world)

	// Entities
	active_entity, has_active_entity := world_get_entity(
		&ctx.game_state.world,
		ctx.active_entity_id,
	).(^Entity)

	if has_active_entity {
		entity_step(ctx, active_entity)
	}

	// Hand
	hand_step_player(ctx)
	hand_step(ctx)

	// Input
	if rl.IsKeyPressed(.ENTER) {
		send_package(
			ctx.socket_event,
			Client_To_Server{player_id = ctx.player_id, end_turn = End_Turn{}},
		)
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
		for x in 0 ..< BOARD_WIDTH {
			for y in 0 ..< BOARD_HEIGHT {
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

		draw_text(format(rl.GetFPS()), {16, 0})
		draw_text(format("You are", ctx.game_state.player_color), {16, 32})
		draw_text(format(ctx.game_state.active_color, "to play"), {16, 64})
		// Cards are drawn on y=96
		draw_text(
			format("Mana:", ctx.game_state.mana, "/", ctx.game_state.max_mana),
			{16, 128},
		)

		hand_draw_gui(&ctx.physical_hand, camera)
	}
	rl.EndDrawing()
}
