package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Card_Kind :: enum {
	squire,
	knight,
	ranger,
	swordsman,
	bomber,
	king,
	adrenaline,
	give_arms,
	halt,
	poisonous_bush,
	guard,
	armory,
	market,
	university,
	library,
}

Card_Category :: enum {
	piece,
	spell,
}

Card_Handle :: struct {
	id:   u64,
	kind: Card_Kind,
}

Card :: struct {
	kind:        Card_Kind,
	name:        string,
	description: string,
	category:    Card_Category,
	cost:        int,
	sprite_id:   Sprite_Id,
	play:        proc(_: ^Server_Game_State, _: Piece_Color, _: IVec2) -> bool,
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
	image_scale := 4 * card.scale
	color := ctx.game_state.player_color
	sprite_draw(
		card.card.sprite_id,
		image_position,
		image_scale,
		{0, cast(int)color},
	)
}

card_get_outline_color :: proc(card: ^Card) -> rl.Color {
	switch card.category {
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

card_get :: proc(card_id: Card_Kind) -> Card {
	switch card_id {
	case .squire:
		return Card {
			kind = .squire,
			name = "Squire",
			category = Card_Category.piece,
			description = "Moves forward",
			cost = 1,
			sprite_id = .squire,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
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
			kind = .knight,
			name = "Knight",
			category = Card_Category.piece,
			description = "Moves forward,\nthen forward diagonally\nuntil there is no piece\ndirectly in front",
			cost = 2,
			sprite_id = .knight,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
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
			kind = .ranger,
			name = "Ranger",
			category = Card_Category.piece,
			description = "@Capturing\nIf an enemy piece\nis visible on a diagonal,\ncapture it",
			cost = 4,
			sprite_id = .ranger,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
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
			kind = .swordsman,
			name = "Swordsman",
			category = Card_Category.piece,
			description = "@Capturing\nMoves forward",
			cost = 3,
			sprite_id = .swordsman,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
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
			kind = .bomber,
			name = "Bomber",
			category = Card_Category.piece,
			description = "Moves forward as far\nas it can before placing\na bomb and fleeing.\nBombs explode,\ndestroying all pieces\nin a 3x3 area",
			cost = 3,
			sprite_id = .bomber,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
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
			kind = .king,
			name = "King",
			category = Card_Category.piece,
			description = "Moves forward\nAllows spawning pieces\nin a 3x3 area around it",
			cost = 4,
			sprite_id = .king,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .king,
							color = color,
							position = position,
							spawn_aura = .square3x3,
						},
					) !=
					nil \
				)
			},
		}
	case .adrenaline:
		return Card {
			kind = .adrenaline,
			name = "Adrenaline",
			category = Card_Category.spell,
			description = "Trigger a piece twice.\nIt won't trigger until\nthe start of your\nnext turn",
			cost = 2,
			sprite_id = .adrenaline,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity := world_get_entity(
					&game_state.world,
					position,
				).(^Entity) or_return
				entity_id := entity.id
				entity.exhausted_for_turns = 2
				entity_run_action(game_state, entity)

				entity_fresh_ptr, not_dead := world_get_entity(
					&game_state.world,
					entity_id,
				).(^Entity)
				if not_dead {
					entity_run_action(game_state, entity_fresh_ptr)
				}

				return true
			},
		}
	case .give_arms:
		return Card {
			kind = .give_arms,
			name = "Give Arms",
			category = Card_Category.spell,
			description = "Give a piece the\nability to capture",
			cost = 3,
			sprite_id = .give_arms,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity, found := world_get_entity(
					&game_state.world,
					position,
				).(^Entity)
				found or_return
				entity.capturing = true
				world_push_entity_history(&game_state.world)
				return true
			},
		}
	case .halt:
		return Card {
			kind = .halt,
			name = "Halt",
			category = Card_Category.spell,
			description = "Move a piece to\nits previous position",
			cost = 1,
			sprite_id = .halt,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				entity, found := world_get_entity(
					&game_state.world,
					position,
				).(^Entity)
				found or_return
				ok := world_try_move_entity(
					&game_state.world,
					entity,
					entity.position_prev,
				)
				return ok
			},
		}
	case .poisonous_bush:
		return Card {
			kind = .poisonous_bush,
			name = "Poisonous Bush",
			category = Card_Category.piece,
			description = "Does not move\nPieces that capture it\nare destroyed",
			cost = 2,
			sprite_id = .poisonous_bush,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .poisonous_bush,
							color = color,
							poisonous = true,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .guard:
		return Card {
			kind = .guard,
			name = "Guard",
			category = Card_Category.piece,
			description = "Makes the piece\nto the left\nand right",
			cost = 3,
			sprite_id = .guard,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .guard,
							color = color,
							position = position,
							immune_aura = .square3x3,
						},
					) !=
					nil \
				)
			},
		}
	case .armory:
		return Card {
			kind = .armory,
			name = "Armory",
			category = Card_Category.piece,
			description = "Gives all pieces\nthe ability\nto capture",
			cost = 6,
			sprite_id = .armory,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .armory,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .market:
		return Card {
			kind = .market,
			name = "Market",
			category = Card_Category.piece,
			description = "Draw a card",
			cost = 4,
			sprite_id = .market,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .market,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .university:
		return Card {
			kind = .university,
			name = "University",
			category = Card_Category.piece,
			description = "Draw a squire card",
			cost = 5,
			sprite_id = .university,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .university,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
			},
		}
	case .library:
		return Card {
			kind = .library,
			name = "Library",
			category = Card_Category.piece,
			description = "+1 to max mana",
			cost = 4,
			sprite_id = .library,
			play = proc(
				game_state: ^Server_Game_State,
				color: Piece_Color,
				position: IVec2,
			) -> bool {
				return(
					player_try_place_entity(
						&game_state.world,
						Entity {
							kind = .library,
							color = color,
							position = position,
						},
					) !=
					nil \
				)
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
