#+vet unused shadowing using-stmt style semicolon
package main

import "core:encoding/json"
import "core:math"
import "core:math/rand"

Game_State :: struct {
	world:             World,
	graphics:          Graphics,
	hand:              Hand,
	deck:              Deck,
	current_entity_id: int,
}

@(private = "file")
_Serializable_Game_State :: struct {
	entities:  [dynamic]Entity,
	player_id: int,
}

game_state_create :: proc() -> Game_State {
	game_state := Game_State{}

	// World
	for _ in 0 ..< 2 {
		position := i_vec_2(
			math.floor(rand.float32() * SURFACE_WIDTH / GRID_SIZE),
			math.floor(rand.float32() * SURFACE_HEIGHT / GRID_SIZE),
		)
		world_add_entity(
			&game_state.world,
			Entity {
				kind = .enemy,
				sprite_id = .skeleton,
				position = position,
				health = 2,
			},
		)
	}

	// Deck
	card_ids: []Card_Id = {.dagger, .dagger, .fire_ball}
	for _ in 0 ..< 100 {
		card_id := rand.choice(card_ids)
		card := card_get(card_id)
		append(&game_state.deck.cards, card)
	}

	// Hand
	game_state.hand.cards_max = 8
	game_state.hand.cards_regen = 1
	for _ in 0 ..< 4 {
		hand_draw_from_deck(&game_state.hand, &game_state.deck)
	}

	return game_state
}

game_state_serialize :: proc(
	game_state: ^Game_State,
) -> (
	data: []byte,
	err: json.Marshal_Error,
) {

	serializable := _Serializable_Game_State {
		entities = game_state.world.entities,
	}
	return json.marshal(serializable)
}

game_state_deserialize :: proc(data: []byte) -> Game_State {
	serializable: _Serializable_Game_State
	json.unmarshal(data, &serializable)

	game_state := Game_State{}
	game_state.world.entities = serializable.entities

	return game_state
}
