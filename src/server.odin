#+vet unused shadowing using-stmt style semicolon
package main
import "core:net"
import "core:thread"

Player_Id :: distinct u32

Server_Game_State :: struct {
	world:            World,
	is_white_to_play: bool,
	white:            Player,
	black:            Player,
}

Server_Context :: struct {
	game_state:    Maybe(Server_Game_State),
	sockets_event: map[Player_Id]net.TCP_Socket,
	sockets_state: map[Player_Id]net.TCP_Socket,
	message_queue: Message_Queue(Client_To_Server),
}

Player :: struct {
	id:   Player_Id,
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

		if len(sockets) == 2 {
			game_start(ctx)
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

game_start :: proc(ctx: ^Server_Context) {

	game_state := Server_Game_State {
		is_white_to_play = true,
	}

	for player_id in ctx.sockets_event {
		player := Player {
			id   = player_id,
			deck = random_deck(),
		}
		for _ in 0 ..< CARDS_MAX {
			hand_draw_from_deck(&player.hand, &player.deck)
		}
		if game_state.white.id == 0 {
			game_state.white = player
			break
		}
		if game_state.black.id == 0 {
			game_state.black = player
			break
		}
	}

	ctx.game_state = game_state
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

		game_state, ok := &ctx.game_state.(Server_Game_State)

		if !ok do continue
		if len(ctx.message_queue.queue) == 0 do continue

		msg := pop(&ctx.message_queue.queue)

		game_update_from_message(ctx, msg)

		for player_id, socket in ctx.sockets_state {
			player_active := false
			hand: Hand
			if player_id == game_state.white.id {
				hand = game_state.white.hand
				player_active = game_state.is_white_to_play
			}
			if player_id == game_state.black.id {
				hand = game_state.black.hand
				player_active = !game_state.is_white_to_play
			}

			send_package(
				socket,
				Server_To_Client {
					client_game_state = Client_Game_State {
						world = game_state.world,
						hand = hand,
						player_active = player_active,
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

	game_state, ok := ctx.game_state.(Server_Game_State)
	if !ok do return

	player: ^Player
	if msg.id == game_state.white.id {
		player = &game_state.white
	}
	if msg.id == game_state.black.id {
		player = &game_state.black
	}
	if player == nil {
		log_red("Player not found", msg.id)
		return
	}

	for &entity in game_state.world.entities {
		entity.draw_position = f_vec_2(entity.position)
	}

	_, is_end_turn := msg.content.end_turn.(End_Turn)
	if is_end_turn {
		// Draw cards
		for len(player.hand.cards) < CARDS_MAX && len(player.deck.cards) > 0 {
			hand_draw_from_deck(&player.hand, &player.deck)
		}

		// Move pieces
		// TODO: decide piece order
		for &entity in game_state.world.entities {
			entity_run_action(&game_state.world, &entity)
		}

		// Activate next player
		game_state.is_white_to_play = !game_state.is_white_to_play
	}

	_, is_deck := msg.content.deck.(Deck)
	if is_deck {

	}

	card_action, is_card_action := msg.content.card_action.(Card_Action)
	if is_card_action {
		card_id := player.hand.cards[card_action.card_idx]
		card := card_get(card_id)
		card.play(&game_state.world, card_action.target)

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
