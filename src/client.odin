#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/rand"
import "core:net"
import "core:slice"
import "core:sync"

Client_Context :: struct {
	player_id:                 Player_Id,
	game_state:                Client_Game_State,
	game_state_incoming:       Maybe(Client_Game_State),
	game_state_incoming_mutex: sync.Recursive_Mutex,
	physical_hand:             Physical_Hand,
	graphics:                  Graphics,
	socket_event:              net.TCP_Socket,
	socket_state:              net.TCP_Socket,
	active_entity_id:          int,
}

Client_To_Server :: struct {
	player_id:   Player_Id,
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

	ctx.player_id = Player_Id(rand.uint64())

	socket_event, socket_event_err := net.dial_tcp(
		net.Endpoint{address = SERVER_ADDR, port = SERVER_PORT_EVENT},
	)
	assert(socket_event_err == nil, format(socket_event_err))
	send_package(socket_event, Client_To_Server{player_id = ctx.player_id})
	ctx.socket_event = socket_event

	socket_state, socket_state_err := net.dial_tcp(
		net.Endpoint{address = SERVER_ADDR, port = SERVER_PORT_STATE},
	)
	assert(socket_state_err == nil, format(socket_state_err))
	send_package(socket_state, Client_To_Server{player_id = ctx.player_id})
	ctx.socket_state = socket_state

	init_msg := Client_To_Server {
		player_id = ctx.player_id,
		deck      = random_deck(),
	}
	send_package(socket_event, init_msg)

	return ctx
}

recv_state_from_server :: proc(ctx_raw_ptr: rawptr) {
	ctx := (^Client_Context)(ctx_raw_ptr)
	for true {
		content: Server_To_Client

		if !recv_package(ctx.socket_state, &content) do continue

		game_state_incoming, ok := content.client_game_state.(Client_Game_State)
		assert(ok, "non-exhaustive")

		sync.recursive_mutex_lock(&ctx.game_state_incoming_mutex)
		ctx.game_state_incoming = game_state_incoming
		sync.recursive_mutex_unlock(&ctx.game_state_incoming_mutex)
	}
}

game_state_apply_incoming :: proc(ctx: ^Client_Context) {
	locked := sync.recursive_mutex_try_lock(&ctx.game_state_incoming_mutex)
	defer sync.recursive_mutex_unlock(&ctx.game_state_incoming_mutex)

	if !locked do return

	game_state_incoming, ok := ctx.game_state_incoming.(Client_Game_State)
	if !ok do return

	ctx.game_state = game_state_incoming
	ctx.game_state_incoming = nil

	if len(ctx.game_state.world.entities) > 0 {
		ctx.active_entity_id = ctx.game_state.world.entities[0].id
	}

	cards_prev := slice.mapper(
		ctx.physical_hand.cards[:],
		proc(card: Physical_Card) -> Card_Id {return card.card.id},
	)
	defer delete(cards_prev)

	if !slice.equal(cards_prev, ctx.game_state.hand.cards[:]) {
		clear(&ctx.physical_hand.cards)

		for card_id in ctx.game_state.hand.cards {
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
