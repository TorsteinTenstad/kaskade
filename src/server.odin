#+vet unused shadowing using-stmt style semicolon
package main
import "core:net"
import "core:thread"

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

Server_To_Client :: struct {
	client_game_state: Maybe(Client_Game_State),
}

Message :: struct($T: typeid) {
	id:      Player_Id,
	content: T,
}

Message_Queue :: struct($T: typeid) {
	queue: [dynamic]Message(T),
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
		thread.create_and_start_with_data(&params, proc(raw_ptr: rawptr) {
			params_ptr := (^Handle_Client_Params)(raw_ptr)
			handle_client(params_ptr)
			free(params_ptr)
		})
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

game_loop :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)

	// active_player_id: int // TODO: fix

	for true {
		if len(ctx.message_queue.queue) == 0 do continue

		msg := pop(&ctx.message_queue.queue)

		//TODO: if msg.id != active_player_id do continue

		game_update_from_message(ctx, msg)

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

game_update_from_message :: proc(
	ctx: ^Server_Context,
	msg: Message(Client_To_Server),
) {
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
		card_id := player.hand.cards[card_action.card_idx]
		card := card_get(card_id)
		card.play(&ctx.world, card_action.target)
		print("PLAY:", card_id)

		ordered_remove(&player.hand.cards, card_action.card_idx)
	}
}

Handle_Client_Params :: struct {
	player_id:     Player_Id,
	message_queue: ^Message_Queue(Client_To_Server),
	socket:        net.TCP_Socket,
}

handle_client :: proc(params: ^Handle_Client_Params) {
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
