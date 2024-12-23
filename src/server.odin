#+vet unused shadowing using-stmt style semicolon
package main
import "core:net"
import "core:slice"
import "core:thread"

Player_Id :: distinct u32

Server_Context :: struct {
	world:         World,
	players:       map[Player_Id]Player,
	player_active: Player_Id,
	sockets_event: map[Player_Id]net.TCP_Socket,
	sockets_state: map[Player_Id]net.TCP_Socket,
	message_queue: Message_Queue(Client_To_Server),
}

Player :: struct {
	hand: Hand,
	deck: Deck,
}

Client_Game_State :: struct {
	world:         World,
	hand:          Hand,
	player_active: bool,
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

		player_id, ok := endpoint_to_player_id(ip).(Player_Id)
		if !ok do continue

		sockets[player_id] = client_socket

		if !is_event do continue

		if len(ctx.players) == 0 {
			ctx.player_active = player_id
		}

		if player_id not_in ctx.players {
			player := Player {
				deck = random_deck(),
			}
			for _ in 0 ..< CARDS_MAX {
				hand_draw_from_deck(&player.hand, &player.deck)
			}
			ctx.players[player_id] = player
		}

		params := new(Handle_Client_Params)
		params.player_id = player_id
		params.message_queue = &ctx.message_queue
		params.socket = client_socket

		thread.create_and_start_with_data(params, proc(raw_ptr: rawptr) {
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
		&ctx.sockets_event,
		net.Endpoint{port = SERVER_PORT_EVENT, address = SERVER_ADDR},
		is_event = true,
	)
}

listen_state :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)
	listen_tcp(
		ctx,
		&ctx.sockets_state,
		net.Endpoint{port = SERVER_PORT_STATE, address = SERVER_ADDR},
		is_event = false,
	)
}

endpoint_to_player_id :: proc(endpoint: net.Endpoint) -> Maybe(Player_Id) {
	switch addr in endpoint.address {
	case net.IP4_Address:
		id: u32
		for i in 0 ..< 4 {
			id += u32(addr[i]) << uint(i * 8)
		}
		return Player_Id(id)
	case net.IP6_Address:
		return nil
	}
	return nil
}

server_start :: proc(ctx: ^Server_Context) {
	thread.create_and_start_with_data(ctx, listen_event)
	thread.create_and_start_with_data(ctx, listen_state)
	thread.create_and_start_with_data(ctx, game_loop)
}

game_loop :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)

	for true {
		if len(ctx.message_queue.queue) == 0 do continue

		msg := pop(&ctx.message_queue.queue)

		if msg.id != ctx.player_active {
			log_red("You", msg.id, "are not active", ctx.player_active)
			continue
		}

		game_update_from_message(ctx, msg)

		for player_id, socket in ctx.sockets_state {
			hand := ctx.players[player_id].hand
			send_package(
				socket,
				Server_To_Client {
					client_game_state = Client_Game_State {
						world = ctx.world,
						hand = hand,
						player_active = player_id == ctx.player_active,
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
		log_red("Player not found", msg.id)
		return
	}
	player := &ctx.players[msg.id]

	for &entity in ctx.world.entities {
		entity.draw_position = f_vec_2(entity.position)
	}

	_, is_end_turn := msg.content.end_turn.(End_Turn)
	if is_end_turn {
		// Draw cards
		for len(player.hand.cards) < CARDS_MAX {
			hand_draw_from_deck(&player.hand, &player.deck)
		}

		// Move pieces
		// TODO: decide piece order
		for &entity in ctx.world.entities {
			entity_run_action(&ctx.world, &entity)
		}

		// Activate next player
		players, _ := slice.map_keys(ctx.players)
		player_idx, found := slice.linear_search(players, msg.id)
		if found {
			player_next_idx := (player_idx + 1) % len(players)
			ctx.player_active = players[player_next_idx]
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

		ordered_remove(&player.hand.cards, card_action.card_idx)
	}
}

Handle_Client_Params :: struct {
	player_id:     Player_Id,
	message_queue: ^Message_Queue(Client_To_Server),
	socket:        net.TCP_Socket,
}

handle_client :: proc(params: ^Handle_Client_Params) {
	log_yellow(
		"Player",
		params.player_id,
		"Connected on socket",
		params.socket,
	)

	for true {
		content: Client_To_Server
		if !recv_package(params.socket, &content) do continue
		msg := Message(Client_To_Server) {
			id      = params.player_id,
			content = content,
		}
		append(&params.message_queue.queue, msg) // TODO: not thread safe!
	}
	log_yellow("Player", params.player_id, "disconnected")
	net.close(params.socket)
}
