#+vet unused shadowing using-stmt style semicolon
package main
import "core:net"
import "core:thread"

Player_Id :: distinct u64 //uuid

Server_Game_State :: struct {
	world:        World,
	active_color: Piece_Color,
	white:        Player,
	black:        Player,
	mana:         int,
}

Server_Context :: struct {
	server_ip:     net.IP4_Address,
	game_state:    Maybe(Server_Game_State),
	sockets_event: map[Player_Id]net.TCP_Socket,
	sockets_state: map[Player_Id]net.TCP_Socket,
	decks:         map[Player_Id]Deck,
	message_queue: Message_Queue(Client_To_Server),
}

Player :: struct {
	id:    Player_Id,
	color: Piece_Color,
	mana:  int,
	hand:  Hand,
	deck:  Deck,
}

Client_Game_State :: struct {
	world:        World,
	hand:         Hand,
	player_color: Piece_Color,
	active_color: Piece_Color,
	mana:         int,
	mana_max:     int,
}

Server_To_Client :: struct {
	client_game_state: Maybe(Client_Game_State),
}

Message_Queue :: struct($T: typeid) {
	queue: [dynamic]T,
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
		if is_event {
			log_yellow("Event listener accepted connection from", ip)
		} else {
			log_yellow("State listener accepted connection from", ip)
		}
		assert(accept_err == nil, format(accept_err))

		init_msg: Client_To_Server
		if !recv_package(client_socket, &init_msg) do continue

		sockets[init_msg.player_id] = client_socket

		if !is_event {
			game_state_send(ctx, init_msg.player_id)
			continue
		}
		recv_deck(ctx, init_msg)

		if len(sockets) == 2 {
			game_start(ctx)
		}

		params := new(Handle_Client_Params)
		params.player_id = init_msg.player_id
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
		active_color = Piece_Color.white,
		mana         = 1,
	}
	log_magenta("Starting game with players", ctx.sockets_event)
	for player_id, _ in ctx.sockets_event {
		player := Player {
			id   = player_id,
			deck = deck_random(),
		}
		if player_id in ctx.decks {
			player.deck = ctx.decks[player_id]
		}
		for _ in 0 ..< CARDS_STARTING {
			hand_draw_from_deck(&player.hand, &player.deck)
		}
		if game_state.white.id == 0 {
			log_magenta("White player is", player_id)
			player.color = Piece_Color.white
			game_state.white = player
			game_state.white.mana = game_state.mana
			continue
		}
		if game_state.black.id == 0 {
			log_magenta("Black player is", player_id)
			player.color = Piece_Color.black
			game_state.black = player
			continue
		}
	}

	ctx.game_state = game_state

	for player_id in ctx.sockets_state {
		game_state_send(ctx, player_id)
	}
}

listen_event :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)
	listen_tcp(
		ctx,
		&ctx.sockets_event,
		net.Endpoint{port = SERVER_PORT_EVENT, address = ctx.server_ip},
		is_event = true,
	)
}

listen_state :: proc(raw_ptr: rawptr) {
	ctx := (^Server_Context)(raw_ptr)
	listen_tcp(
		ctx,
		&ctx.sockets_state,
		net.Endpoint{port = SERVER_PORT_STATE, address = ctx.server_ip},
		is_event = false,
	)
}

recv_deck :: proc(ctx: ^Server_Context, msg: Client_To_Server) -> bool {
	deck := msg.deck.(Deck) or_return
	ctx.decks[msg.player_id] = deck
	deck_shuffle(&ctx.decks[msg.player_id])
	return true
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
		game_update_from_message(ctx, msg)

		for player_id in ctx.sockets_state {
			game_state_send(ctx, player_id)
		}
	}
}

game_state_send :: proc(ctx: ^Server_Context, player_id: Player_Id) -> bool {
	game_state := (&ctx.game_state.(Server_Game_State)) or_return

	player: ^Player
	if player_id == game_state.white.id {
		player = &game_state.white
	}
	if player_id == game_state.black.id {
		player = &game_state.black
	}

	client_game_state := Client_Game_State {
		world        = game_state.world,
		active_color = game_state.active_color,
	}

	if player != nil {
		client_game_state.hand = player.hand
		client_game_state.player_color = player.color
		client_game_state.mana = player.mana
		client_game_state.mana_max = game_state.mana
	}

	send_package(
		ctx.sockets_state[player_id],
		Server_To_Client{client_game_state = client_game_state},
	)
	return true
}

game_update_from_message :: proc(
	ctx: ^Server_Context,
	msg: Client_To_Server,
) -> bool {
	game_state := (&ctx.game_state.(Server_Game_State)) or_return

	world := &game_state.world
	player: ^Player

	if msg.player_id == game_state.white.id &&
	   game_state.active_color == Piece_Color.white {
		player = &game_state.white
	}
	if msg.player_id == game_state.black.id &&
	   game_state.active_color == Piece_Color.black {
		player = &game_state.black
	}
	if player == nil {
		if msg.player_id == game_state.white.id ||
		   msg.player_id == game_state.black.id {
			log_red("Not your turn", msg.player_id)
		} else {
			log_red("Player not found", msg.player_id)
		}
		return false
	}

	for &entity in world.entities {
		entity.position_draw = f_vec_2(entity.position)
	}

	_, is_end_turn := msg.end_turn.(End_Turn)
	if is_end_turn {
		// Draw cards
		for _ in 0 ..< CARDS_DRAWN {
			if len(player.hand.cards) < CARDS_MAX &&
			   len(player.deck.cards) > 0 {
				hand_draw_from_deck(&player.hand, &player.deck)
			}
		}

		// Move pieces
		// TODO: decide piece order
		{
			entity_ids := world_get_entity_ids(world)
			defer delete(entity_ids)

			for id in entity_ids {
				entity := world_get_entity(world, id).(^Entity) or_continue
				entity.exhausted_for_turns = max(
					0,
					entity.exhausted_for_turns - 1,
				)
				if entity.color != game_state.active_color do continue
				if entity.exhausted_for_turns > 0 do continue
				entity_run_action(game_state, entity)
			}
		}
		{
			entity_ids := world_get_entity_ids(world)
			defer delete(entity_ids)

			for id in entity_ids {
				entity := world_get_entity(world, id).(^Entity) or_continue
				if entity.kind == Entity_Kind.bomb do continue
				if player_in_win_zone(entity.color, entity.position) {
					log_magenta(entity.color, "gained 1 point")
					if entity.color == Piece_Color.white {
						game_state.world.points_white += 1
					} else {
						game_state.world.points_black += 1
					}
					world_remove_entity(world, id)
				}
			}
		}


		// Update max mana
		if game_state.active_color == Piece_Color.white {
			game_state.mana = min(MANA_MAX, game_state.mana + 1)
		}

		// Activate next player and refill their mana
		if game_state.active_color == Piece_Color.black {
			game_state.active_color = Piece_Color.white
			game_state.white.mana = game_state.mana

			for &entity in world.entities { 	// TODO: If we do more mana manipulation, we should have better systems
				if entity.kind == Entity_Kind.library &&
				   entity.color == Piece_Color.white {
					game_state.white.mana += 1
				}
			}
		} else {
			game_state.active_color = Piece_Color.black
			game_state.black.mana = game_state.mana

			for &entity in world.entities { 	// TODO: If we do more mana manipulation, we should have better systems
				if entity.kind == Entity_Kind.library &&
				   entity.color == Piece_Color.black {
					game_state.black.mana += 1
				}
			}
		}

		log_magenta(game_state.active_color, "to play")
	}

	_, is_deck := msg.deck.(Deck)
	if is_deck {

	}

	card_action, is_card_action := msg.card_action.(Card_Action)
	if is_card_action {
		if card_action.card_idx < len(player.hand.cards) {
			card_handle := player.hand.cards[card_action.card_idx]
			card := card_get(card_handle.kind)
			if card.cost <= player.mana {
				if card.play(game_state, player.color, card_action.target) {
					log_magenta(
						game_state.active_color,
						"played",
						card_handle.kind,
					)
					player.mana -= card.cost
					ordered_remove(&player.hand.cards, card_action.card_idx)
				}
			}
		} else {
			log_red("Invalid card index", card_action.card_idx)
		}
	}
	return true
}

Handle_Client_Params :: struct {
	player_id:     Player_Id,
	message_queue: ^Message_Queue(Client_To_Server),
	socket:        net.TCP_Socket,
}

handle_client :: proc(params: ^Handle_Client_Params) {
	for true {
		msg: Client_To_Server
		if !recv_package(params.socket, &msg) do continue
		if msg.player_id == 0 {
			log_red("Client_To_Server missing player_id")
		}

		append(&params.message_queue.queue, msg) // TODO: not thread safe!
	}
	net.close(params.socket)
}
