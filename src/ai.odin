#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/rand"
import "core:time"

ai_run :: proc() {
	active_color: Piece_Color = nil

	ctx := headless_client_context_create()

	server_to_client: Server_To_Client
	for true {
		recv_ok := recv_package(ctx.socket_state, &server_to_client)
		if !recv_ok {
			continue
		}

		game_state, ok := &server_to_client.client_game_state.(Client_Game_State)
		if !ok do continue

		if game_state.player_color == game_state.active_color &&
		   game_state.active_color != active_color {

			ai_do_action(&ctx, game_state)
		}
		active_color = game_state.active_color
	}
}

ai_do_action :: proc(
	ctx: ^Headless_Client_Context,
	game_state: ^Client_Game_State,
) {
	if len(game_state.hand.cards) > 0 {

		time.sleep(time.Second)

		card_idx := rand.int_max(len(game_state.hand.cards))

		card := card_get(game_state.hand.cards[card_idx])
		target := IVec2{rand.int_max(BOARD_WIDTH), rand.int_max(BOARD_HEIGHT)}

		if card.kind == Card_Kind.piece {
			if game_state.player_color == Piece_Color.black {
				target = IVec2{rand.int_max(BOARD_WIDTH), rand.int_max(2)}
			}
			if game_state.player_color == Piece_Color.white {
				target = IVec2 {
					rand.int_max(BOARD_WIDTH),
					BOARD_HEIGHT - 1 - rand.int_max(2),
				}
			}
		}

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

	time.sleep(time.Second)

	send_package(
		ctx.socket_event,
		Client_To_Server{player_id = ctx.player_id, end_turn = End_Turn{}},
	)
}
