#+vet unused shadowing using-stmt style semicolon
package main

import rl "vendor:raylib"

Camera :: struct {
	position:        FVec2,
	target_position: FVec2,
	view_size:       IVec2,
}

camera_step :: proc(camera: ^Camera, world: ^World) {
	target_position_world :=
		camera.target_position - f_vec_2(camera.view_size) / 2

	scale := camera_surface_scale(camera)
	target_position := target_position_world * GRID_SIZE * scale

	camera.position = move_towards(
		camera.position,
		target_position,
		CAMERA_SPEED,
		0.25,
	)
}

camera_gui_mouse_position :: proc(camera: ^Camera) -> FVec2 {
	mouse_screen_position := rl.GetMousePosition()
	origin := camera_surface_origin(camera)
	return mouse_screen_position - origin
}

camera_world_mouse_position :: proc(camera: ^Camera) -> IVec2 {
	return camera_gui_to_world(camera, camera_gui_mouse_position(camera))
}

camera_gui_size :: proc() -> FVec2 {
	return f_vec_2(rl.GetScreenWidth(), rl.GetScreenHeight())
}

camera_surface_scale :: proc(camera: ^Camera) -> f32 {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())
	surface_width := f32(SURFACE_WIDTH)
	surface_height := f32(SURFACE_HEIGHT)
	return max(screen_width / surface_width, screen_height / surface_height)
}

camera_surface_origin :: proc(camera: ^Camera) -> FVec2 {
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())
	surface_width := f32(SURFACE_WIDTH)
	surface_height := f32(SURFACE_HEIGHT)
	scale := camera_surface_scale(camera)
	return FVec2 {
		(screen_width - surface_width * scale) * 0.5,
		(screen_height - surface_height * scale) * 0.5,
	}
}

@(private = "file")
_camera_world_to_surface_i :: proc(camera: ^Camera, value: int) -> f32 {
	return camera_world_to_surface(camera, f32(value))
}

@(private = "file")
_camera_world_to_surface_f :: proc(camera: ^Camera, value: f32) -> f32 {
	return value * GRID_SIZE
}

@(private = "file")
_camera_world_to_surface_i_vec :: proc(
	camera: ^Camera,
	position: IVec2,
) -> FVec2 {
	return camera_world_to_surface(camera, f_vec_2(position))
}

@(private = "file")
_camera_world_to_surface_f_vec :: proc(
	camera: ^Camera,
	position: FVec2,
) -> FVec2 {
	scale := camera_surface_scale(camera)
	return position * GRID_SIZE - floor_vec(camera.position / scale)
}

@(private = "file")
_camera_world_to_surface_rect :: proc(
	camera: ^Camera,
	rect: rl.Rectangle,
) -> rl.Rectangle {
	position := camera_world_to_surface(camera, FVec2{rect.x, rect.y})
	width := rect.width * GRID_SIZE
	height := rect.height * GRID_SIZE
	return rl.Rectangle{position.x, position.y, width, height}
}

camera_world_to_surface :: proc {
	_camera_world_to_surface_i,
	_camera_world_to_surface_f,
	_camera_world_to_surface_i_vec,
	_camera_world_to_surface_f_vec,
	_camera_world_to_surface_rect,
}

camera_gui_to_world :: proc(camera: ^Camera, position: FVec2) -> IVec2 {
	scale := camera_surface_scale(camera)
	return i_vec_2((position + camera.position) / (GRID_SIZE * scale))
}

@(private = "file")
_camera_world_to_gui_f_vec :: proc(camera: ^Camera, position: FVec2) -> FVec2 {
	scale := camera_surface_scale(camera)
	origin := camera_surface_origin(camera)
	surface_position := camera_world_to_surface(camera, position)
	subpixel := FVec2 {
		floor_to_multiple(camera.position.x, scale) - camera.position.x,
		floor_to_multiple(camera.position.y, scale) - camera.position.y,
	}
	return origin + surface_position * scale + subpixel
}

@(private = "file")
_camera_world_to_gui_i_vec :: proc(camera: ^Camera, position: IVec2) -> FVec2 {
	return _camera_world_to_gui_f_vec(camera, f_vec_2(position))
}

camera_world_to_gui :: proc {
	_camera_world_to_gui_f_vec,
	_camera_world_to_gui_i_vec,
}
