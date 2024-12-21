#+vet unused shadowing using-stmt style semicolon
package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

print :: proc(args: ..any, sep := " ", flush := true) {
	fmt.println(args, sep = sep, flush = flush)
}

cstr :: proc(str: string) -> cstring {
	return strings.clone_to_cstring(str)
}

format :: proc(args: ..any, sep := " ") -> string {
	return fmt.tprint(..args, sep = sep)
}

draw_text :: proc(
	text: string,
	position: FVec2,
	size: f32 = 32,
	color: rl.Color = rl.WHITE,
	font: Font_Id = FONT_DEFAULT,
) {
	rl.DrawTextEx(
		get_game_state().graphics.fonts[font],
		cstr(text),
		position,
		size,
		0,
		color,
	)
}
