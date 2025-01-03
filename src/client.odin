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
	physical_hand:                   Physical_Hand,
	graphics:                        Graphics,
	audio:                           Audio,
	entity_history_animation_idx:    int,
	entity_history_animation_lerp_t: f32,
	player_id:                       Player_Id,
	game_state:                      Client_Game_State,
	game_state_incoming:             Maybe(Client_Game_State),
	game_state_incoming_mutex:       sync.Recursive_Mutex,
	socket_event:                    net.TCP_Socket,
	socket_state:                    net.TCP_Socket,
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

	for i := len(ctx.physical_hand.cards) - 1; i >= 0; i -= 1 {
		physical_card := &ctx.physical_hand.cards[i]
		found := false
		for card_handle in ctx.game_state.hand.cards {
			if physical_card.id == card_handle.id {
				found = true
				break
			}
		}
		if !found {
			hand_unhover(&ctx.physical_hand)
			ordered_remove(&ctx.physical_hand.cards, i)
		}
	}

	for card_handle in ctx.game_state.hand.cards {
		found := false
		for physical_card in ctx.physical_hand.cards {
			if physical_card.id == card_handle.id {
				found = true
				break
			}
		}
		if !found {
			append(
				&ctx.physical_hand.cards,
				Physical_Card {
					id = card_handle.id,
					card = card_get(card_handle.kind),
				},
			)
		}
	}

	return true
}
