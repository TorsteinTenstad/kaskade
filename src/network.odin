#+vet unused shadowing using-stmt style semicolon
package main

import "core:encoding/json"
import "core:mem"
import "core:net"
import "core:slice"
import "core:thread"

Card_Action :: struct {
	card_idx: int,
	target:   IVec2,
}

End_Turn :: struct {}

Server_To_Client :: struct {
	client_game_state: Maybe(Client_Game_State),
}

Client_To_Server :: struct {
	deck:        Maybe(Deck),
	card_action: Maybe(Card_Action),
	end_turn:    Maybe(End_Turn),
}

Message :: struct($T: typeid) {
	id:      Player_Id,
	content: T,
}

Message_Queue :: struct($T: typeid) {
	queue: [dynamic]Message(T),
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

	print("Sent", string(buf))
}

recv_package :: proc(socket: net.TCP_Socket, msg: $T) -> bool {
	size_bytes: [8]u8
	size_bytes_read, recv_size_err := net.recv_tcp(socket, size_bytes[:])

	(size_bytes_read != 0) or_return

	(recv_size_err == nil && size_bytes_read == 8) or_return

	size := int(transmute(u64)(size_bytes))

	buf := make([]u8, size)
	defer delete(buf)
	msg_bytes_read, recv_buf_error := net.recv_tcp(socket, buf)

	(recv_buf_error == nil && msg_bytes_read == size) or_return

	json.unmarshal(buf, msg)

	print("Recv'd!")

	return true
}

random_deck :: proc() -> Deck {
	deck: Deck
	append(&deck.cards, Card_Id.dagger)
	append(&deck.cards, Card_Id.dagger)
	append(&deck.cards, Card_Id.skeleton)
	append(&deck.cards, Card_Id.dagger)
	append(&deck.cards, Card_Id.skeleton)
	append(&deck.cards, Card_Id.fire_ball)
	append(&deck.cards, Card_Id.dagger)
	append(&deck.cards, Card_Id.skeleton)
	append(&deck.cards, Card_Id.dagger)
	append(&deck.cards, Card_Id.fire_ball)
	append(&deck.cards, Card_Id.fire_ball)
	append(&deck.cards, Card_Id.skeleton)
	append(&deck.cards, Card_Id.fire_ball)
	append(&deck.cards, Card_Id.skeleton)
	return deck
}

listen_tcp :: proc(
	ctx: ^Server_Context,
	sockets: ^map[Player_Id]net.TCP_Socket,
	endpoint: net.Endpoint,
	is_event: bool,
) {
	socket_state, socket_state_err := net.listen_tcp(endpoint)
	assert(socket_state_err == nil, format(socket_state_err))
	for true {
		client_socket, ip, accept_err := net.accept_tcp(socket_state)
		assert(accept_err == nil, format(accept_err))
		id: u32
		switch addr in ip.address {
		case net.IP4_Address:
			for i in 0 ..< 4 {
				id += u32(addr[i]) << uint(i * 8)
			}
		case net.IP6_Address:
		// TODO

		}

		if id == 0 do continue

		player_id := Player_Id(id)
		sockets[player_id] = client_socket
		if player_id not_in ctx.players {
			player := Player {
				deck = random_deck(),
			}
			for _ in 0 ..< CARDS_MAX {
				hand_draw_from_deck(&player.hand, &player.deck)
			}
			ctx.players[player_id] = player
		}

		if !is_event do continue

		params := Handle_Client_Params {
			player_id     = player_id,
			message_queue = &ctx.message_queue,
			socket        = client_socket,
		}
		thread.create_and_start_with_data(&params, handle_client)
	}
}

listen_event :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)
	listen_tcp(
		ctx,
		&ctx.socket_event,
		net.Endpoint{port = SERVER_PORT_EVENT, address = SERVER_ADDR},
		true,
	)
}

listen_state :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)
	listen_tcp(
		ctx,
		&ctx.socket_state,
		net.Endpoint{port = SERVER_PORT_STATE, address = SERVER_ADDR},
		false,
	)
}

server_start :: proc(ctx: ^Server_Context) {
	thread.create_and_start_with_data(ctx, listen_event)
	thread.create_and_start_with_data(ctx, listen_state)
	thread.create_and_start_with_data(ctx, game_loop)
}

_game_loop_raw_ptr :: proc(raw_ptr: rawptr) {
	ctx_ptr := (^Server_Context)(raw_ptr)
	game_loop(ctx_ptr)
}

_game_loop :: proc(ctx: ^Server_Context) {
	// active_player_id: int // TODO: fix

	for true {
		if len(ctx.message_queue.queue) == 0 do continue

		msg := pop(&ctx.message_queue.queue)

		//TODO: if msg.id != active_player_id do continue

		game_step(ctx, msg)

		for player_id, socket in ctx.socket_state {
			hand := ctx.players[Player_Id(player_id)].hand
			send_package(
				socket,
				Server_To_Client {
					client_game_state = Client_Game_State {
						world = ctx.world,
						hand = hand,
					},
				},
			)
		}
	}
}

game_loop :: proc {
	_game_loop,
	_game_loop_raw_ptr,
}

game_step :: proc(ctx: ^Server_Context, msg: Message(Client_To_Server)) {
	if msg.id not_in ctx.players {
		print("Player not found", msg.id)
		return
	}
	player := &ctx.players[msg.id]

	_, is_end_turn := msg.content.end_turn.(End_Turn)
	if is_end_turn {
		for len(player.hand.cards) < CARDS_MAX {
			hand_draw_from_deck(&player.hand, &player.deck)
		}
	}

	_, is_deck := msg.content.deck.(Deck)
	if is_deck {

	}

	card_action, is_card_action := msg.content.card_action.(Card_Action)
	if is_card_action {
		ordered_remove(&player.hand.cards, card_action.card_idx)
	}
}

Handle_Client_Params :: struct {
	player_id:     Player_Id,
	message_queue: ^Message_Queue(Client_To_Server),
	socket:        net.TCP_Socket,
}

_handle_client_raw_ptr :: proc(raw_ptr: rawptr) {
	params_ptr := (^Handle_Client_Params)(raw_ptr)
	_handle_client(params_ptr)
	free(params_ptr)
}

_handle_client :: proc(params: ^Handle_Client_Params) {
	print("Hello client!", params.socket)

	for true {
		content: Client_To_Server
		if recv_package(params.socket, &content) {
			msg := Message(Client_To_Server) {
				id      = params.player_id,
				content = content,
			}
			append(&params.message_queue.queue, msg) // TODO: not thread safe!
		} else {
			break
		}
	}

	print("Goodbye client!", params.socket)
	net.close(params.socket)
}

handle_client :: proc {
	_handle_client,
	_handle_client_raw_ptr,
}

read_state_from_network :: proc(ctx_raw_ptr: rawptr) {
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
