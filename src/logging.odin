package main

import "core:fmt"

set_terminal_color :: proc(color_code: u8) {
	fmt.print("\033[38;5;", color_code, "m", sep = "")
}

reset_terminal_color :: proc() {
	fmt.println("\033[0m")
}

log_red :: proc(message: ..any, loc := #caller_location) {
	set_terminal_color(202)
	defer reset_terminal_color()
	fmt.print(..message)
	fmt.print(" |", loc)
}

log_yellow :: proc(message: ..any, loc := #caller_location) {
	set_terminal_color(220)
	defer reset_terminal_color()
	fmt.print(..message)
}

log_green :: proc(message: ..any, loc := #caller_location) {
	set_terminal_color(77)
	defer reset_terminal_color()
	fmt.print(..message)
}

log_blue :: proc(message: ..any, loc := #caller_location) {
	set_terminal_color(39)
	defer reset_terminal_color()
	fmt.print(..message)
}

log_magenta :: proc(message: ..any, loc := #caller_location) {
	set_terminal_color(213)
	defer reset_terminal_color()
	fmt.print(..message)
}
