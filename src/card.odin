package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Card_Id :: enum {
	skeleton,
	dagger,
	fire_ball,
}

Card :: struct {
	name:        string,
	attack:      int,
	play:        proc(_: ^World, _: IVec2) -> bool,
	range:       f32,
	description: string,
	unbreakable: bool,
}

card_draw_gui :: proc(card: ^PhysicalCard) {
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
	if card.unbreakable do return rl.BLUE
	return rl.BLACK
}

card_get_rect :: proc(card: ^PhysicalCard) -> rl.Rectangle {
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
	case .skeleton:
		return Card {
			name = "Skeleton",
			description = "Spawn a skelly",
			play = proc(world: ^World, position: IVec2) -> bool {
				world_add_entity(
					world,
					Entity {
						kind = .enemy,
						sprite_id = .skeleton,
						position = position,
					},
				)
				return true
			},
			range = 4.2,
		}
	case .dagger:
		return Card {
			name = "Dagger",
			description = "Deal 2 dmg",
			play = proc(world: ^World, position: IVec2) -> bool {
				entity, hit := world_get_entity(world, position).(^Entity)
				if hit {
					entity.health -= 2
					if entity.health <= 0 {
						world_remove_entity(world, entity)
					}
				}
				return hit
			},
			range = 1.2,
		}
	case .fire_ball:
		return Card {
			name = "Fire Ball",
			description = "Deal 6 dmg",
			play = proc(world: ^World, position: IVec2) -> bool {
				entity, hit := world_get_entity(world, position).(^Entity)
				if hit {
					entity.health -= 6
					if entity.health <= 0 {
						world_remove_entity(world, entity)
					}
				}
				return hit
			},
			range = 2.2,
		}
	}
	return Card {
		name = "Empty",
		play = proc(world: ^World, position: IVec2) -> bool {
			return true
		},
	}
}

card_get_positions :: proc(card: ^Card) -> []IVec2 {
	positions: []IVec2 = {}
	return positions
}
