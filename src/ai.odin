#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/rand"

ai_run :: proc() {
	is_active_player := false

	ctx := headless_client_context_create()

	server_to_client: Server_To_Client
	for true {
		recv_ok := recv_package(ctx.socket_state, &server_to_client)
		if !recv_ok {
			continue
		}

		game_state, ok := &server_to_client.client_game_state.(Client_Game_State)
		if !ok do continue

		if game_state.is_active_player &&
		   game_state.is_active_player != is_active_player {

			ai_do_action(&ctx, game_state)
		}
		is_active_player = game_state.is_active_player
	}
}

ai_do_action :: proc(
	ctx: ^Headless_Client_Context,
	game_state: ^Client_Game_State,
) {
	if len(game_state.hand.cards) > 0 {
		card_idx := rand.int_max(len(game_state.hand.cards))
		target := IVec2{rand.int_max(8), rand.int_max(8)}

		send_package(
			ctx.socket_event,
			Client_To_Server {
				player_id = ctx.player_id,
				card_action = Card_Action {
					card_idx = card_idx,
					target = target,
				},
			},
		)
	}

	send_package(
		ctx.socket_event,
		Client_To_Server{player_id = ctx.player_id, end_turn = End_Turn{}},
	)
}
