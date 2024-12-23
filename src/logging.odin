package main

import "core:fmt"

print_colored :: proc(
	color_code: u8,
	loc := #caller_location,
	print_loc: bool = false,
	message: ..any,
) {
	terminal_set_color := fmt.tprint("\033[38;5;", color_code, "m", sep = "")
	message_text := fmt.tprint(..message)
	terminal_reset_color := "\033[0m"
	loc_text := ""
	if print_loc {
		loc_text = fmt.tprint(" | ", loc, sep = "")
	}
	fmt.println(
		terminal_set_color,
		message_text,
		loc_text,
		terminal_reset_color,
		sep = "",
	)
}
log_red :: proc(message: ..any, loc := #caller_location) {
	print_colored(202, loc, true, ..message)
}

log_yellow :: proc(message: ..any, loc := #caller_location) {
	print_colored(220, loc, false, ..message)
}

log_green :: proc(message: ..any, loc := #caller_location) {
	print_colored(77, loc, false, ..message)
}

log_blue :: proc(message: ..any, loc := #caller_location) {
	print_colored(39, loc, false, ..message)
}

log_magenta :: proc(message: ..any, loc := #caller_location) {
	print_colored(213, loc, false, ..message)
}
