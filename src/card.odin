package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Card_Id :: enum {
	squire,
	knight,
	ranger,
	swordsman,
	bomber,
	king,
	adrenaline,
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
	texture:     Texture_Color_Agnostic,
	play:        proc(_: ^World, _: Piece_Color, _: IVec2) -> bool,
}

card_draw_gui :: proc(card: ^Physical_Card) {
	rect := card_get_rect(card)
	rl.DrawRectangleRounded(rect, 0.2, 8, rl.WHITE)
	outline_color := card_get_outline_color(&card.card)
	rl.DrawRectangleRoundedLinesEx(rect, 0.2, 8, 4, outline_color)
	text_position := FVec2 {
		rect.x + rect.width * 0.1,
		rect.y + rect.height * 0.4,
	}
	mana_position := FVec2 {
		rect.x + rect.width * 0.77,
		rect.y + rect.height * 0.03,
	}

	draw_text(
		card.card.name,
		text_position,
		size = 24 * card.scale,
		color = rl.BLACK,
		font = .nova_square_regular,
	)

	draw_text(
		format(card.card.cost),
		mana_position,
		size = 36 * card.scale,
		color = rl.BLUE,
		font = .nova_square_regular,
	)

	description_position := text_position + FVec2{-4, 32} * card.scale
	draw_text(
		card.card.description,
		description_position,
		size = 12 * card.scale,
		color = rl.BLACK,
		font = .nova_square_regular,
	)

	ctx := get_context()
	image_position := FVec2 {
		rect.x + rect.width * 0.1,
		rect.y + rect.height * 0.03,
	}
	texture :=
		ctx.game_state.player_color == Piece_Color.black ? card.card.texture.black : card.card.texture.white
	image_scale := 4 * card.scale
	rl.DrawTextureEx(texture, image_position, 0, image_scale, rl.WHITE)
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
	case .squire:
		return Card {
			id = .squire,
			name = "Squire",
			kind = Card_Kind.piece,
			description = "Moves forward",
			cost = 1,
			texture = entity_get_texture_color_agnostic(.squire),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .squire,
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
			description = "Moves forward,\nthen forward diagonally\nuntil there is no piece\ndirectly in front",
			cost = 2,
			texture = entity_get_texture_color_agnostic(.knight),
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
	case .ranger:
		return Card {
			id = .ranger,
			name = "Ranger",
			kind = Card_Kind.piece,
			description = "@Capturing\nIf an enemy piece\nis visible on a diagonal,\ncapture it",
			cost = 3,
			texture = entity_get_texture_color_agnostic(.ranger),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .ranger,
							color = color,
							capturing = true,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .swordsman:
		return Card {
			id = .swordsman,
			name = "Swordsman",
			kind = Card_Kind.piece,
			description = "@Capturing\nMoves forward",
			cost = 3,
			texture = entity_get_texture_color_agnostic(.swordsman),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .swordsman,
							capturing = true,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .bomber:
		return Card {
			id = .bomber,
			name = "Bomber",
			kind = Card_Kind.piece,
			description = "Moves forward as far\nas it can before placing\na bomb and fleeing.\nBombs explode,\ndestroying all pieces\nin a 3x3 area",
			cost = 3,
			texture = entity_get_texture_color_agnostic(.bomber),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						world,
						Entity {
							kind = .bomber,
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
			description = "Moves forward\nAllows spawning pieces\nin a 3x3 area around it",
			cost = 4,
			texture = entity_get_texture_color_agnostic(.king),
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
	case .adrenaline:
		return Card {
			id = .adrenaline,
			name = "Adrenaline",
			kind = Card_Kind.spell,
			description = "Trigger a piece twice.\nIt won't trigger until\nthe start of your\nnext turn",
			cost = 2,
			texture = get_texture_as_agnostic(.adrenaline),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity := world_get_entity(world, position).(^Entity) or_return
				entity_id := entity.id
				entity.exhausted_for_turns = 2
				entity_run_action(world, entity)

				entity_fresh_ptr, not_dead := world_get_entity(
					world,
					entity_id,
				).(^Entity)
				if not_dead {
					entity_run_action(world, entity_fresh_ptr)
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
			texture = get_texture_as_agnostic(.give_arms),
			play = proc(
				world: ^World,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity, found := world_get_entity(world, position).(^Entity)
				found or_return
				entity.capturing = true
				world_push_entity_history(world)
				return true
			},
		}
	case .halt:
		return Card {
			id = .halt,
			name = "Halt",
			kind = Card_Kind.spell,
			description = "Move a piece to\nits previous position",
			cost = 1,
			texture = get_texture_as_agnostic(.halt),
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
