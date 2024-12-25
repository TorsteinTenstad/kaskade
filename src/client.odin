#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/rand"
import "core:net"
import "core:sync"

Headless_Client_Context :: struct {
	player_id:    Player_Id,
	socket_event: net.TCP_Socket,
	socket_state: net.TCP_Socket,
}

Client_Context :: struct {
	physical_hand:             Physical_Hand,
	graphics:                  Graphics,
	audio:                     Audio,
	active_entity_id:          int,
	player_id:                 Player_Id,
	game_state:                Client_Game_State,
	game_state_incoming:       Maybe(Client_Game_State),
	game_state_incoming_mutex: sync.Recursive_Mutex,
	socket_event:              net.TCP_Socket,
	socket_state:              net.TCP_Socket,
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

client_context_create :: proc(
	server_ip: net.IP4_Address,
	deck: Maybe(Deck) = nil,
) -> Client_Context {
	ctx := Client_Context{}

	headless_ctx := headless_client_context_create(server_ip, deck)

	ctx.player_id = headless_ctx.player_id
	ctx.socket_event = headless_ctx.socket_event
	ctx.socket_state = headless_ctx.socket_state

	return ctx
}

headless_client_context_create :: proc(
	server_ip: net.IP4_Address,
	deck: Maybe(Deck) = nil,
) -> Headless_Client_Context {
	ctx := Headless_Client_Context{}

	ctx.player_id = Player_Id(rand.uint64())

	socket_event, socket_event_err := net.dial_tcp(
		net.Endpoint{address = server_ip, port = SERVER_PORT_EVENT},
	)
	assert(socket_event_err == nil, format(socket_event_err))
	send_package(
		socket_event,
		Client_To_Server{player_id = ctx.player_id, deck = deck},
	)
	ctx.socket_event = socket_event

	socket_state, socket_state_err := net.dial_tcp(
		net.Endpoint{address = server_ip, port = SERVER_PORT_STATE},
	)
	assert(socket_state_err == nil, format(socket_state_err))
	send_package(socket_state, Client_To_Server{player_id = ctx.player_id})
	ctx.socket_state = socket_state

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

game_state_apply_incoming :: proc(ctx: ^Client_Context) -> bool {
	sync.recursive_mutex_try_lock(&ctx.game_state_incoming_mutex) or_return
	defer sync.recursive_mutex_unlock(&ctx.game_state_incoming_mutex)

	game_state_incoming :=
		ctx.game_state_incoming.(Client_Game_State) or_return

	ctx.game_state = game_state_incoming
	ctx.game_state_incoming = nil

	if len(ctx.game_state.world.entities) > 0 {
		ctx.active_entity_id = ctx.game_state.world.entities[0].id
	}

	cards_equal :=
		len(ctx.physical_hand.cards) == len(ctx.game_state.hand.cards)

	if cards_equal {
		for i in 0 ..< len(ctx.physical_hand.cards) {
			if ctx.physical_hand.cards[i].card.id !=
			   ctx.game_state.hand.cards[i] {
				cards_equal = false
				break
			}
		}
	}

	if !cards_equal {
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
	}

	return true
}
