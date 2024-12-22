#+vet unused shadowing using-stmt style semicolon
package main

import "core:net"

Server_Context :: struct {
	world:         World,
	clients:       [dynamic]Client,
	message_queue: Message_Queue(Client_To_Server),
}

Client :: struct {
	socket: net.TCP_Socket,
	// message_queue: ^Message_Queue(Client_To_Server),
	hand:   Hand,
	deck:   Deck,
}

Client_Game_State :: struct {
	world: World,
	hand:  Hand,
}

Client_Context :: struct {
	game_state:    Client_Game_State,
	physical_hand: Physical_Hand,
	graphics:      Graphics,
	socket:        net.TCP_Socket,
}

client_context_create :: proc() -> Client_Context {
	ctx := Client_Context{}

	socket, err := net.dial_tcp(
		net.Endpoint{address = SERVER_ADDR, port = PORT},
	)
	assert(err == nil, format(err))

	ctx.socket = socket
	net.set_blocking(ctx.socket, false)

	return ctx
}
