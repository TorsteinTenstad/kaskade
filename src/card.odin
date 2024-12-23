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

Card_Kind :: enum {
	piece,
	spell,
}

Card :: struct {
	id:          Card_Id,
	name:        string,
	description: string,
	kind:        Card_Kind,
	play:        proc(_: ^World, _: Piece_Color, _: IVec2) -> bool,
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
	switch card.kind {
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
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity{kind = .pawn, color = color, position = position},
				)
				return true
			},
		}
	case .knight:
		return Card {
			name = "Knight",
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity{kind = .knight, color = color, position = position},
				)
				return true
			},
		}
	case .bishop:
		return Card {
			name = "Bishop",
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity {
						kind = .bishop,
						color = color,
						capturing = true,
						position = position,
					},
				)
				return true
			},
		}
	case .rook:
		return Card {
			name = "Rook",
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity {
						kind = .rook,
						color = color,
						capturing = true,
						position = position,
					},
				)
				return true
			},
		}
	case .queen:
		return Card {
			name = "Queen",
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity{kind = .queen, color = color, position = position},
				)
				return true
			},
		}
	case .king:
		return Card {
			name = "King",
			kind = Card_Kind.piece,
			description = "TODO: description",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				world_add_entity(
					world,
					Entity{kind = .king, color = color, position = position},
				)
				return true
			},
		}
	case .obduction:
		return Card {
			name = "Obduction",
			kind = Card_Kind.spell,
			description = "Remove all pieces in a 3x3 square.",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				death_note := make([dynamic]int)
				defer delete(death_note)

				for &entity in world.entities {
					distance_vec := position - entity.position
					if abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1 {
						append(&death_note, entity.id)
					}
				}
				for entity_id in death_note {
					world_remove_entity(world, entity_id)
				}
				return true
			},
		}
	case .haste:
		return Card {
			name = "Haste",
			kind = Card_Kind.spell,
			description = "Trigger a piece",
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
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
