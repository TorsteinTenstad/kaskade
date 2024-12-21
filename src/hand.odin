#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

PhysicalCard :: struct {
	card:            Card,
	position:        FVec2,
	scale:           f32,
	target_position: FVec2,
	target_scale:    f32,
	z_index:         int,
}

Deck :: struct {
	cards: [dynamic]Card,
}

Hand :: struct {
	cards:             [dynamic]PhysicalCard,
	cards_regen:       int,
	cards_max:         int,
	hover_index:       Maybe(int),
	hover_target:      Maybe(IVec2),
	hover_is_selected: bool,
}

hand_step :: proc(game_state: ^Game_State) {
	hand := &game_state.hand

	sorted_indices := sort_indices_by(
		hand.cards[:],
		proc(a: PhysicalCard, b: PhysicalCard) -> bool {
			return a.z_index > b.z_index
		},
	)
	hover_index, is_hovering := hand.hover_index.(int)
	mouse_gui_position := rl.GetMousePosition()

	for i in sorted_indices {
		if is_hovering && hover_index == i do continue

		card := &hand.cards[i]
		card.target_position = _card_position(i, len(hand.cards))
		card.target_scale = 1
		card.z_index = 0

		gui_size := camera_gui_size()
		y_hand := gui_size[1] - CARD_HEIGHT * 1.5
		if hand.hover_is_selected || mouse_gui_position[1] < y_hand {
			card.target_position[1] += CARD_HEIGHT
		}

		hoverable_rect := card_get_rect(card)
		hoverable_rect.height += CARD_HEIGHT
		if !is_hovering &&
		   linalg.distance(card.position, card.target_position) < 2 &&
		   point_in_rect(mouse_gui_position, &hoverable_rect) {
			hand.hover_index = i
		}
	}

	if is_hovering {
		card := &hand.cards[hover_index]
		card.z_index = 1

		if !hand.hover_is_selected {
			card.target_scale = 1.5
			card.target_position =
				_card_position(hover_index, len(hand.cards)) +
				FVec2{0, -CARD_HEIGHT / 2}

			hoverable_rect := card_get_rect(card)
			hoverable_rect.height += CARD_HEIGHT
			mouse_in_rect := point_in_rect(mouse_gui_position, &hoverable_rect)
			if !mouse_in_rect {
				_hand_unhover(hand)
			}
		}
	}

	for &card in hand.cards {
		card.position = move_towards(card.position, card.target_position, 0.2)
		card.scale = move_towards(card.scale, card.target_scale, 0.2)
	}
}

hand_step_player :: proc(game_state: ^Game_State) {
	hand := &game_state.hand
	deck := &game_state.deck
	camera := &game_state.graphics.camera
	world := &game_state.world
	hover_index, is_hovering := hand.hover_index.(int)
	mouse_gui_position := rl.GetMousePosition()

	if is_hovering {
		card := &hand.cards[hover_index]

		if rl.IsMouseButtonPressed(.LEFT) {
			hand.hover_is_selected = true
		}
		if rl.IsMouseButtonPressed(.RIGHT) {
			_hand_unhover(hand)
		}

		if hand.hover_is_selected {
			card.target_scale = 2
			card.target_position =
				mouse_gui_position + FVec2{CARD_WIDTH * 2, CARD_HEIGHT / 2}
			mouse_world_position := camera_world_mouse_position(camera)
			hand.hover_target = mouse_world_position

			if rl.IsMouseButtonReleased(.LEFT) {
				if hand_play(
					hand,
					hover_index,
					deck,
					world,
					mouse_world_position,
				) {
					// player_end_turn(game_state)
				}
				_hand_unhover(hand)
			}
		}
	}
}

@(private = "file")
_hand_unhover :: proc(hand: ^Hand) {
	hand.hover_index = nil
	hand.hover_target = nil
	hand.hover_is_selected = false
}

@(private = "file")
_card_position :: proc(i: int, n: int) -> FVec2 {
	margin :: 32
	gui_size := camera_gui_size()
	origin := FVec2{gui_size.x / 2, gui_size.y - CARD_HEIGHT / 2 - margin}
	width := f32(n) * (CARD_WIDTH + margin)
	offset := FVec2{f32(i) * (CARD_WIDTH + margin) - width / 2, 0}
	return origin + offset
}

hand_play :: proc(
	hand: ^Hand,
	index: int,
	deck: ^Deck,
	world: ^World,
	position: IVec2,
) -> bool {
	if index >= len(hand.cards) do return false

	card := hand.cards[index]
	positions := card_get_positions(&card.card)
	if !slice.contains(positions, position) do return false
	if !card.card.play(world, position) do return false

	if !card.card.unbreakable {
		ordered_remove(&hand.cards, index)
		append(&deck.cards, card.card)
		deck_shuffle(deck)
	}
	return true
}

hand_draw_from_deck :: proc(hand: ^Hand, deck: ^Deck) -> bool {
	if len(hand.cards) >= hand.cards_max do return false

	if len(deck.cards) == 0 do return false

	card := pop(&deck.cards)
	append(&hand.cards, PhysicalCard{card = card})
	return true
}

hand_draw_gui :: proc(hand: ^Hand, camera: ^Camera) {
	sorted_indices := sort_indices_by(
		hand.cards[:],
		proc(a: PhysicalCard, b: PhysicalCard) -> bool {
			return a.z_index < b.z_index
		},
	)
	for i in sorted_indices {
		card_draw_gui(&hand.cards[i])
	}

	_, is_hovering := hand.hover_index.(int)
	hover_target, is_targeting := hand.hover_target.(IVec2)
	if is_hovering && is_targeting {
		gui_position := camera_world_to_gui(camera, hover_target)
		scale := camera_surface_scale(camera)
		rl.DrawRectangleRoundedLines(
			rl.Rectangle {
				gui_position.x,
				gui_position.y,
				GRID_SIZE * scale,
				GRID_SIZE * scale,
			},
			0.1,
			16,
			4,
			rl.WHITE,
		)
	}

	cards_text := format(
		"Cards: ",
		len(hand.cards),
		"/",
		hand.cards_max,
		" |+",
		hand.cards_regen,
	)
	draw_text(cards_text, {16, 96})
}

deck_shuffle :: proc(deck: ^Deck) {
	rand.shuffle(deck.cards[:])
}
