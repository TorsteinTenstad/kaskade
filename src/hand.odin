#+vet unused shadowing using-stmt style semicolon
package main

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

Physical_Card :: struct {
	id:              u64,
	card:            Card,
	position:        FVec2,
	scale:           f32,
	target_position: FVec2,
	target_scale:    f32,
	z_index:         int,
}

Deck :: struct {
	cards: [dynamic]Card_Kind,
}

Hand :: struct {
	cards: [dynamic]Card_Handle,
}

Physical_Hand :: struct {
	cards:             [dynamic]Physical_Card,
	hover_index:       Maybe(int),
	hover_target:      Maybe(IVec2),
	hover_is_selected: bool,
}

hand_step :: proc(ctx: ^Client_Context) {
	card_size := ctx.graphics.gui_scale * FVec2{CARD_WIDTH, CARD_HEIGHT}
	hand := &ctx.physical_hand

	sorted_indices := sort_indices_by(
		hand.cards[:],
		proc(a: Physical_Card, b: Physical_Card) -> bool {
			return a.z_index > b.z_index
		},
	)
	defer delete(sorted_indices)
	hover_index, is_hovering := hand.hover_index.(int)
	mouse_gui_position := rl.GetMousePosition()

	for i in sorted_indices {
		if is_hovering && hover_index == i do continue

		card := &hand.cards[i]
		card.target_position = _card_position(i, len(hand.cards), card_size)
		card.target_scale = 1 * ctx.graphics.gui_scale
		card.z_index = 0

		gui_size := camera_gui_size()
		y_hand := gui_size[1] - card_size[1] * 1.5
		if hand.hover_is_selected || mouse_gui_position[1] < y_hand {
			card.target_position[1] += card_size[1]
		}

		hoverable_rect := card_get_rect(card)
		hoverable_rect.height += card_size[1]
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
			card.target_scale = 1.5 * ctx.graphics.gui_scale
			card.target_position =
				_card_position(hover_index, len(hand.cards), card_size) +
				FVec2{0, -card_size[1] / 2}

			hoverable_rect := card_get_rect(card)
			hoverable_rect.height += card_size[1]
			mouse_in_rect := point_in_rect(mouse_gui_position, &hoverable_rect)
			if !mouse_in_rect {
				hand_unhover(hand)
			}
		}
	}

	for &card in hand.cards {
		card.position = move_towards(card.position, card.target_position, 0.2)
		card.scale = move_towards(card.scale, card.target_scale, 0.2)
	}
}

hand_step_player :: proc(ctx: ^Client_Context) {
	card_size := ctx.graphics.gui_scale * FVec2{CARD_WIDTH, CARD_HEIGHT}
	hand := &ctx.physical_hand
	world := &ctx.game_state.world
	camera := &ctx.graphics.camera
	hover_index, is_hovering := hand.hover_index.(int)
	mouse_gui_position := rl.GetMousePosition()

	if is_hovering {
		card := &hand.cards[hover_index]

		if rl.IsMouseButtonPressed(.LEFT) {
			hand.hover_is_selected = true
		}
		if rl.IsMouseButtonPressed(.RIGHT) {
			hand_unhover(hand)
		}

		if hand.hover_is_selected {
			card.target_scale = 2 * ctx.graphics.gui_scale
			card.target_position =
				mouse_gui_position + FVec2{card_size[0] * 2, card_size[1] / 2}
			mouse_world_position := camera_world_mouse_position(camera)
			hand.hover_target = mouse_world_position
			if ctx.game_state.player_color == Piece_Color.black {
				mouse_world_position.y =
					BOARD_HEIGHT - mouse_world_position.y - 1
				mouse_world_position.x =
					BOARD_WIDTH - mouse_world_position.x - 1
			}

			if rl.IsMouseButtonReleased(.LEFT) {
				hand_unhover(hand)
				hand_play(ctx, hover_index, world, mouse_world_position)
			}
		}
	}
}

hand_unhover :: proc(hand: ^Physical_Hand) {
	hand.hover_index = nil
	hand.hover_target = nil
	hand.hover_is_selected = false
}

@(private = "file")
_card_position :: proc(i: int, n: int, card_size: FVec2) -> FVec2 {
	margin :: 32
	gui_size := camera_gui_size()
	origin := FVec2{gui_size.x / 2, gui_size.y - card_size[1] / 2 - margin}
	width := f32(n) * (card_size[0] + margin)
	offset := FVec2{f32(i) * (card_size[0] + margin) - width / 2, 0}
	return origin + offset
}

hand_play :: proc(
	ctx: ^Client_Context,
	index: int,
	world: ^World,
	position: IVec2,
) -> bool {
	if index >= len(ctx.physical_hand.cards) do return false

	msg: Client_To_Server = Client_To_Server {
		player_id = ctx.player_id,
		card_action = Card_Action{card_idx = index, target = position},
	}
	send_package(ctx.socket_event, msg)

	return true
}

hand_generate_handle :: proc(kind: Card_Kind) -> Card_Handle {
	return Card_Handle{kind = kind, id = rand.uint64()}
}

hand_draw_from_deck :: proc(hand: ^Hand, deck: ^Deck) -> bool {
	if len(hand.cards) >= CARDS_MAX do return false
	if len(deck.cards) == 0 do return false

	card_kind := pop(&deck.cards)
	append(&hand.cards, hand_generate_handle(card_kind))
	return true
}

hand_draw_gui :: proc(hand: ^Physical_Hand, camera: ^Camera) {
	sorted_indices := sort_indices_by(
		hand.cards[:],
		proc(a: Physical_Card, b: Physical_Card) -> bool {
			return a.z_index < b.z_index
		},
	)
	defer delete(sorted_indices)
	for i in sorted_indices {
		card_draw_gui(&hand.cards[i])
	}

	_, is_hovering := hand.hover_index.(int)
	hover_target, is_targeting := hand.hover_target.(IVec2)
	if is_hovering && is_targeting {
		gui_position := camera_world_to_gui(camera, hover_target)
		scale := camera_surface_scale(camera)
		rl.DrawRectangleRoundedLinesEx(
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

	cards_text := format("Cards: ", len(hand.cards), "/", CARDS_MAX)
	draw_text(cards_text, {16, 96})
}

deck_shuffle :: proc(deck: ^Deck) {
	rand.shuffle(deck.cards[:])
}

deck_random :: proc() -> Deck {
	deck: Deck

	for _ in 0 ..< 10 {
		for card_id in Card_Kind {
			if rand.int_max(2) > 0 {
				append(&deck.cards, card_id)
			}
		}
	}

	deck_shuffle(&deck)

	return deck
}
