#+vet unused shadowing using-stmt style semicolon
package main

import "core:encoding/json"
import "core:mem"
import "core:net"
import "core:thread"

Card_Action :: struct {
	card: Card,
	tile: IVec2,
}

End_Turn :: struct {}

Server_To_Client :: union {
	Serializable_Game_State,
}

Client_To_Server :: union {
	Deck,
	Card_Action,
	End_Turn,
}

send_package :: proc(socket: net.TCP_Socket, msg: $T) {
	buf, json_err := json.marshal(msg)

	assert(json_err == nil, format(json_err))

	size: u64 = transmute(u64)len(buf)
	size_bytes := mem.byte_slice(&size, 8)

	sent_bytes: int
	tcp_err: net.Network_Error

	sent_bytes, tcp_err = net.send_tcp(socket, size_bytes)
	assert(tcp_err == nil, format(tcp_err))
	assert(sent_bytes == 8, format(sent_bytes))

	sent_bytes, tcp_err = net.send_tcp(socket, buf)
	assert(tcp_err == nil, format(tcp_err))
	assert(sent_bytes == int(size), format(sent_bytes))
}

recv_package :: proc(socket: net.TCP_Socket, msg: $T) -> bool {
	size_bytes: [8]u8
	size_bytes_read, recv_size_err := net.recv_tcp(socket, size_bytes[:])

	(recv_size_err == nil && size_bytes_read == 4) or_return

	size := transmute(u64)(size_bytes)

	buf := make([]u8, size)
	defer delete(buf)
	msg_bytes_read, recv_buf_error := net.recv_tcp(socket, buf)

	(recv_buf_error == nil && msg_bytes_read == size_bytes_read) or_return

	json.unmarshal(buf, msg)

	return true
}

server_start :: proc() {
	socket, listen_err := net.listen_tcp(
		net.Endpoint{port = 5739, address = net.IP4_Address{192, 168, 1, 113}},
	)
	assert(listen_err == nil, format(listen_err))

	for true {
		client_socket, _, accept_err := net.accept_tcp(socket)
		print("Client socket is", client_socket)

		if accept_err == nil {
			bop := new(net.TCP_Socket)
			bop^ = client_socket
			thread.create_and_start_with_data(bop, handle_client)
		}
	}
}

handle_client :: proc(raw_ptr: rawptr) {
	game_state := game_state_create()
	serializable := Serializable_Game_State {
		entities = game_state.world.entities,
	}

	socket_ptr := (^net.TCP_Socket)(raw_ptr)
	socket := socket_ptr^
	free(socket_ptr)
	print("Hello client!", socket)

	for true {
		send_package(socket, serializable)
		print("Sent package!")

		msg: Client_To_Server
		if recv_package(socket, &msg) {
		} else {
			break
		}
		print("Recv package!")
		print(msg)
	}

	print("Goodbye client!", socket)
	net.close(socket)
}
