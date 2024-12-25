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
	give_arms,
	halt,
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
	cost:        int,
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
			id = .pawn,
			name = "Pawn",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 1,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .pawn,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .knight:
		return Card {
			id = .knight,
			name = "Knight",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 2,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .knight,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .bishop:
		return Card {
			id = .bishop,
			name = "Bishop",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 3,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .bishop,
							color = color,
							capturing = true,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .rook:
		return Card {
			id = .rook,
			name = "Rook",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 3,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .rook,
							capturing = true,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .queen:
		return Card {
			id = .queen,
			name = "Queen",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 4,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .queen,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .king:
		return Card {
			id = .king,
			name = "King",
			kind = Card_Kind.piece,
			description = "TODO: description",
			cost = 4,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .king,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .haste:
		return Card {
			id = .haste,
			name = "Haste",
			kind = Card_Kind.spell,
			description = "Trigger a piece",
			cost = 2,
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
	case .obduction:
		return Card {
			id = .obduction,
			name = "Obduction",
			kind = Card_Kind.spell,
			description = "Remove all pieces in a 3x3 square.",
			cost = 4,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity_ids := world_get_entity_ids(world)
				defer delete(entity_ids)

				for id in entity_ids {
					entity := world_get_entity(world, id).(^Entity) or_continue
					distance_vec := position - entity.position
					if abs(distance_vec.x) <= 1 && abs(distance_vec.y) <= 1 {
						world_remove_entity(world, entity.id)
					}
				}
				return true
			},
		}
	case .give_arms:
		return Card {
			id = .give_arms,
			name = "Give Arms",
			kind = Card_Kind.spell,
			description = "Give a piece the ability to capture",
			cost = 3,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity, found := world_get_entity(world, position).(^Entity)
				found or_return
				entity.capturing = true
				return true
			},
		}
	case .halt:
		return Card {
			id = .halt,
			name = "Halt",
			kind = Card_Kind.spell,
			description = "Move a piece to its previous position",
			cost = 1,
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity, found := world_get_entity(world, position).(^Entity)
				found or_return
				ok := world_try_move_entity(
					world,
					entity,
					entity.position_prev,
				)
				return ok
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
