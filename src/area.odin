package main

Area :: enum {
	adjacent,
	square3x3,
	left_right,
}

area_is_inside :: proc(area: Area, src_pos: IVec2, check_pos: IVec2) -> bool {
	switch area {
	case .adjacent:
		return abs(src_pos.x - check_pos.x) + abs(src_pos.y - check_pos.y) == 1
	case .square3x3:
		return(
			abs(src_pos.x - check_pos.x) <= 1 &&
			abs(src_pos.y - check_pos.y) <= 1 \
		)
	case .left_right:
		return(
			(check_pos.x == src_pos.x - 1 || check_pos.x == src_pos.x + 1) &&
			src_pos.y == check_pos.y \
		)
	}
	assert(false, "non-exhaustive")
	return false
}
