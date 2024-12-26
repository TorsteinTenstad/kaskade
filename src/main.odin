#+vet unused shadowing using-stmt style semicolon
package main

import "core:net"
import "core:os"
import "core:thread"
import rl "vendor:raylib"

@(private = "file")
_client_context: Client_Context

get_context :: proc() -> ^Client_Context {
	return &_client_context
}

Program_Args :: struct {
	run_server:    bool,
	run_ai_client: bool,
	server_ip:     net.IP4_Address,
	deck_path:     string,
}

main :: proc() {
	program_args: Program_Args
	program_args.deck_path = "data/deck.json"
	program_args.server_ip = SERVER_ADDR
	for arg, idx in os.args[:] {
		if arg == "-s" || arg == "--run_server" {
			program_args.run_server = true
		} else if arg == "-a" || arg == "--run_ai" {
			program_args.run_ai_client = true
		} else if arg == "-i" || arg == "--server_ip" {
			if idx + 1 < len(os.args) {
				addr, ok := net.parse_ip4_address(os.args[idx + 1])
				if ok {
					program_args.server_ip = addr
				} else {
					log_red("Invalid IPv4 address", os.args[idx + 1])
				}
			} else {
				log_red("No IP provided after", arg)
			}
		} else if arg == "-d" || arg == "--deck_path" {
			if idx + 1 < len(os.args) {
				program_args.deck_path = os.args[idx + 1]
			} else {
				log_red("No path provided after", arg)
			}
		} else if arg == "-h" || arg == "--help" {
			print("Usage:")
			print("  -s, --run_server")
			print("  -a, --run_ai")
			print("  -i, --server_ip <IP>")
			print("  -d, --deck_path <PATH>")
			print("  -h, --help")
			return
		} else if arg[0] == '-' {
			log_red("Unknown argument", arg)
		}
	}
	log_yellow("Args:", os.args)
	log_yellow("Parsed args:", program_args)
	deck := deck_load_json(program_args.deck_path)

	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	// Server
	if program_args.run_server {
		ctx := Server_Context{}
		server_start(&ctx)
	}

	if program_args.run_ai_client {
		thread.create_and_start_with_data(
			&program_args.server_ip,
			proc(server_ip: rawptr) {
				ai_run((^net.IP4_Address)(server_ip)^)},
		)
	}

	// Client
	_client_context = client_context_create(program_args.server_ip, deck)
	graphics_create(&_client_context)
	audio_load(&_client_context.audio)

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

	// Hand and input
	hand_step(ctx)

	if (ctx.game_state.active_color == ctx.game_state.player_color) {
		hand_step_player(ctx)

		// Input
		if rl.IsKeyPressed(.ENTER) {
			send_package(
				ctx.socket_event,
				Client_To_Server {
					player_id = ctx.player_id,
					end_turn = End_Turn{},
				},
			)
		}
	}
}

COLOR_BACKGROUND_DARK: rl.Color : {21, 18, 20, 255}
COLOR_BACKGROUND_LIGHT: rl.Color : {29, 25, 27, 255}

flip_if_black :: proc(vec: FVec2, color: Piece_Color) -> FVec2 {
	vec := vec
	if color == Piece_Color.black {
		vec.y = BOARD_HEIGHT - vec.y - 1
		vec.x = BOARD_WIDTH - vec.x - 1
	}
	return vec
}

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
			world_positions := card_get_positions(&card.card) // TODO: fix card_get_positions
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
		if ctx.entity_history_animation_idx <
		   (len(ctx.game_state.world.entity_history) - 1) {
			ctx.entity_history_animation_lerp_t += 5 * rl.GetFrameTime()
			if ctx.entity_history_animation_lerp_t >= 1.0 {
				ctx.entity_history_animation_lerp_t -= 1.0
				ctx.entity_history_animation_idx += 1
			}
		}

		if ctx.entity_history_animation_idx <
		   (len(ctx.game_state.world.entity_history) - 1) {
			entities_animation_origin := &ctx.game_state.world.entity_history[ctx.entity_history_animation_idx]
			entities := &ctx.game_state.world.entity_history[ctx.entity_history_animation_idx + 1]
			for &entity in entities {
				found_origin := false
				for &entity_animation_origin in entities_animation_origin {
					if entity.id == entity_animation_origin.id {
						found_origin = true
						position_draw := lerp(
							f_vec_2(entity_animation_origin.position),
							f_vec_2(entity.position),
							ctx.entity_history_animation_lerp_t,
						)
						entity_draw(
							&entity,
							flip_if_black(
								position_draw,
								ctx.game_state.player_color,
							),
						)
						break
					}
				}
				if !found_origin {
					entity_draw(
						&entity,
						flip_if_black(
							f_vec_2(entity.position),
							ctx.game_state.player_color,
						),
					)
				}
			}
		} else if ctx.entity_history_animation_idx <
		   len(ctx.game_state.world.entity_history) {
			entities := &ctx.game_state.world.entity_history[ctx.entity_history_animation_idx]
			for &entity in entities {
				entity_draw(
					&entity,
					flip_if_black(
						f_vec_2(entity.position),
						ctx.game_state.player_color,
					),
				)
			}
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
			format("Mana:", ctx.game_state.mana, "/", ctx.game_state.mana_max),
			{16, 128},
		)
		draw_text("Points:", {16, 160})
		draw_text(
			format("\tWhite:", ctx.game_state.world.points_black),
			{16, 192},
		)
		draw_text(
			format("\tBlack:", ctx.game_state.world.points_white),
			{16, 224},
		)

		hand_draw_gui(&ctx.physical_hand, camera)
	}
	rl.EndDrawing()
}
