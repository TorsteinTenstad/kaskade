#+vet unused shadowing using-stmt style semicolon
package main

import "core:net"
import "core:slice"

Client_Context :: struct {
	game_state:    Client_Game_State,
	physical_hand: Physical_Hand,
	graphics:      Graphics,
	socket_event:  net.TCP_Socket,
	socket_state:  net.TCP_Socket,
}

Client_To_Server :: struct {
	deck:        Maybe(Deck),
	card_action: Maybe(Card_Action),
	end_turn:    Maybe(End_Turn),
}

Card_Action :: struct {
	card_idx: int,
	target:   IVec2,
}

End_Turn :: struct {}

client_context_create :: proc() -> Client_Context {
	ctx := Client_Context{}

	socket_event, socket_event_err := net.dial_tcp(
		net.Endpoint{address = SERVER_ADDR, port = SERVER_PORT_EVENT},
	)
	assert(socket_event_err == nil, format(socket_event_err))
	ctx.socket_event = socket_event

	socket_state, socket_state_err := net.dial_tcp(
		net.Endpoint{address = SERVER_ADDR, port = SERVER_PORT_STATE},
	)
	assert(socket_state_err == nil, format(socket_state_err))
	ctx.socket_state = socket_state

	init_msg := Client_To_Server {
		deck = random_deck(),
	}
	send_package(socket_event, init_msg)

	return ctx
}

recv_state_from_server :: proc(ctx_raw_ptr: rawptr) {
	ctx := (^Client_Context)(ctx_raw_ptr)
	for true {
		content: Server_To_Client

		if !recv_package(ctx.socket_state, &content) do continue
		client_game_state, ok := content.client_game_state.(Client_Game_State)
		assert(ok, "non-exhaustive")

		ctx.game_state = client_game_state

		cards_prev := slice.mapper(
			ctx.physical_hand.cards[:],
			proc(card: Physical_Card) -> Card_Id {return card.card.id},
		)
		defer delete(cards_prev)

		if !slice.equal(cards_prev, client_game_state.hand.cards[:]) {
			clear(&ctx.physical_hand.cards)
			print(client_game_state.hand.cards)

			for card_id in client_game_state.hand.cards {
				append(
					&ctx.physical_hand.cards,
					Physical_Card{card = card_get(card_id)},
				)
			}
			ctx.physical_hand.hover_index = nil
			ctx.physical_hand.hover_is_selected = false
			ctx.physical_hand.hover_target = nil

			// TODO: Fix animations
		}
	}
}
