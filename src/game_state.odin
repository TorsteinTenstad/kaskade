#+vet unused shadowing using-stmt style semicolon
package main

import "core:net"

Player_Id :: distinct u32
Server_Context :: struct {
	world:         World,
	players:       map[Player_Id]Player,
	socket_event:  map[Player_Id]net.TCP_Socket,
	socket_state:  map[Player_Id]net.TCP_Socket,
	message_queue: Message_Queue(Client_To_Server),
}

Player :: struct {
	hand: Hand,
	deck: Deck,
}

Client_Game_State :: struct {
	world: World,
	hand:  Hand,
}

Client_Context :: struct {
	game_state:    Client_Game_State,
	physical_hand: Physical_Hand,
	graphics:      Graphics,
	socket_event:  net.TCP_Socket,
	socket_state:  net.TCP_Socket,
}

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
