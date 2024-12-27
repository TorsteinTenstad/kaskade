#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/rand"
import "core:net"

ai_run :: proc(server_ip: net.IP4_Address) {
	deck := deck_load_json("data/ai_deck.json")

	ctx := headless_client_context_create(server_ip, deck)

	server_to_client: Server_To_Client
	for true {
		recv_ok := recv_package(ctx.socket_state, &server_to_client)
		if !recv_ok {
			log_red("recv_package failed")
			continue
		}

		game_state, ok := &server_to_client.client_game_state.(Client_Game_State)
		if !ok {
			log_red("non-exhaustive")
		}

		if game_state.player_color == game_state.active_color {
			found_something_to_play := ai_do_action(&ctx, game_state)
			if !found_something_to_play {
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
}

hand_find_card :: proc(hand: ^Hand, card_kind: Card_Kind) -> Maybe(int) {
	for c, idx in hand.cards {
		if c.kind == card_kind do return idx
	}
	return nil
}

play :: proc(ctx: ^Headless_Client_Context, card_idx: int, target: IVec2) {
	send_package(
		ctx.socket_event,
		Client_To_Server {
			player_id = ctx.player_id,
			card_action = Card_Action{card_idx = card_idx, target = target},
		},
	)
}


ai_do_action :: proc(
	ctx: ^Headless_Client_Context,
	game_state: ^Client_Game_State,
) -> bool {
	// Check for good give arms target
	if game_state.mana >= 3 {
		for &entity in game_state.world.entities {
			if entity.kind != Entity_Kind.squire do continue
			if entity.color != game_state.player_color do continue
			if entity.capturing do continue
			if world_is_empty(&game_state.world, entity.position + entity_direction_y(entity.color)) do continue
			card_idx := hand_find_card(
				&game_state.hand,
				Card_Kind.give_arms,
			).(int) or_continue
			play(ctx, card_idx, entity.position)
			return true
		}
	}

	// Play a random squire
	if game_state.mana >= 1 {
		card_idx := hand_find_card(
			&game_state.hand,
			Card_Kind.squire,
		).(int) or_return

		target: IVec2
		if game_state.player_color == Piece_Color.black {
			target = IVec2{rand.int_max(BOARD_WIDTH), rand.int_max(2)}
		}
		if game_state.player_color == Piece_Color.white {
			target = IVec2 {
				rand.int_max(BOARD_WIDTH),
				BOARD_HEIGHT - 1 - rand.int_max(2),
			}
		}

		play(ctx, card_idx, target)
		return true
	}

	return false
}
