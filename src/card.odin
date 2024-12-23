package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Card_Id :: enum {
	pawn,
	knight,
	bishop,
	rook,
	queen,
	king,
	haste,
	obduction,
}

Card_Type :: enum {
	piece,
	spell,
}
Card :: struct {
	id:          Card_Id,
	name:        string,
	description: string,
	type:        Card_Type,
	play:        proc(_: ^World, _: IVec2) -> bool,
}

card_draw_gui :: proc(card: ^Physical_Card) {
	rect := card_get_rect(card)
	rl.DrawRectangleRounded(rect, 0.2, 8, rl.WHITE)
	outline_color := card_get_outline_color(&card.card)
	rl.DrawRectangleRoundedLines(rect, 0.2, 8, 8, outline_color)
	text_position := FVec2{rect.x + rect.width * 0.1, rect.y + rect.height / 2}
	draw_text(
		card.card.name,
		text_position,
		size = 24 * card.scale,
		color = rl.BLACK,
		font = .nova_square_regular,
	)

	description_position := text_position + FVec2{0, 32} * card.scale
	draw_text(
		card.card.description,
		description_position,
		size = 16 * card.scale,
		color = rl.BLACK,
		font = .nova_square_regular,
	)
}

card_get_outline_color :: proc(card: ^Card) -> rl.Color {
	switch card.type {
	case .piece:
		return rl.BLACK
	case .spell:
		return rl.BLUE

	}
	assert(false, "non-exhaustive")
	return rl.BLACK
}

card_get_rect :: proc(card: ^Physical_Card) -> rl.Rectangle {
	width := card.scale * CARD_WIDTH
	height := card.scale * CARD_HEIGHT
	return rl.Rectangle {
		x = card.position.x - width / 2,
		y = card.position.y - height / 2,
		width = width,
		height = height,
	}
}

card_get :: proc(card_id: Card_Id) -> Card {
	switch card_id {
	case .pawn:
		return Card {
			name = "Pawn",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .pawn,
						sprite_id = .pawn,
						position = position,
					},
				)
				return true
			},
		}
	case .knight:
		return Card {
			name = "Knight",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .knight,
						sprite_id = .knight,
						position = position,
					},
				)
				return true
			},
		}
	case .bishop:
		return Card {
			name = "Bishop",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .bishop,
						sprite_id = .bishop,
						position = position,
					},
				)
				return true
			},
		}
	case .rook:
		return Card {
			name = "Rook",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .rook,
						sprite_id = .rook,
						position = position,
					},
				)
				return true
			},
		}
	case .queen:
		return Card {
			name = "Queen",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .queen,
						sprite_id = .queen,
						position = position,
					},
				)
				return true
			},
		}
	case .king:
		return Card {
			name = "King",
			description = "TODO: description",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						action_id = .king,
						sprite_id = .king,
						position = position,
					},
				)
				return true
			},
		}
	case .obduction:
		return Card {
			name = "Obduction",
			description = "Remove all pieces in a 3x3 square.",
			play = proc(world: ^World, position: IVec2) -> bool {
				for &entity in world.entities {
					distance_vec := position - entity.position
					if (abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1) {
						world_remove_entity(world, &entity)
					}
				}
				return true
			},
		}
	case .haste:
		return Card {
			name = "Haste",
			description = "Trigger a piece",
			play = proc(world: ^World, position: IVec2) -> bool {
				entity, found := world_get_entity(world, position).(^Entity)
				found or_return
				entity_run_action(world, entity)
				return true
			},
		}
	}
	assert(false, "non-exhaustive")
	return Card{}
}

card_get_positions :: proc(card: ^Card) -> []IVec2 {
	positions: []IVec2 = {}
	return positions
}
