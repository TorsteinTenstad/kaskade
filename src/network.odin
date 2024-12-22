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
	id:      int,
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

server_start :: proc() {
	ctx: Server_Context

	socket, listen_err := net.listen_tcp(
		net.Endpoint{port = PORT, address = SERVER_ADDR},
	)
	assert(listen_err == nil, format(listen_err))

	thread.create_and_start_with_data(&ctx, game_loop)

	for true {
		client_socket, _, accept_err := net.accept_tcp(socket)

		if accept_err != nil do continue

		client := Client {
			socket = client_socket,
			deck   = random_deck(),
		}

		for (len(client.hand.cards) < CARDS_MAX) {
			hand_draw_from_deck(&client.hand, &client.deck)
		}
		append(&ctx.clients, client)

		params := new(Handle_Client_Params)
		params.socket = client.socket
		params.message_queue = &ctx.message_queue

		thread.create_and_start_with_data(params, handle_client)

		send_package(
			client.socket,
			Server_To_Client {
				client_game_state = Client_Game_State {
					hand = client.hand,
					world = ctx.world,
				},
			},
		)
	}
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

		// if msg.id != active_player_id do continue

		game_step(ctx, msg)

		for client in ctx.clients {
			send_package(
				client.socket,
				Server_To_Client {
					client_game_state = Client_Game_State {
						world = ctx.world,
						hand = client.hand,
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
	client_ids := slice.mapper(ctx.clients[:], proc(c: Client) -> int {
			return int(c.socket)
		})
	client_idx, found := slice.linear_search(client_ids, msg.id)
	if !found do return

	client := &ctx.clients[client_idx]

	_, is_end_turn := msg.content.end_turn.(End_Turn)
	if is_end_turn {
		for len(client.hand.cards) < CARDS_MAX {
			hand_draw_from_deck(&client.hand, &client.deck)
		}
	}

	_, is_deck := msg.content.deck.(Deck)
	if is_deck {

	}

	card_action, is_card_action := msg.content.card_action.(Card_Action)
	if is_card_action {
		ordered_remove(&client.hand.cards, card_action.card_idx)
	}
}

Handle_Client_Params :: struct {
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
				id      = int(params.socket), // TODO: use ip?
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

network_step :: proc(ctx: ^Client_Context) {

	content: Server_To_Client

	if recv_package(ctx.socket, &content) {
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
