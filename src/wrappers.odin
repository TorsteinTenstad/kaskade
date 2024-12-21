#+vet unused shadowing using-stmt style semicolon
package main

import "core:fmt"
import "core:strings"

print :: proc(args: ..any, sep := " ", flush := true) {
	fmt.println(args, sep = sep, flush = flush)
}

cstr :: proc(str: string) -> cstring {
	return strings.clone_to_cstring(str)
}

format :: proc(args: ..any, sep := " ") -> string {
	return fmt.tprint(..args, sep = sep)
}
