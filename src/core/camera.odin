package ome

import "core:math"
import "core:math/linalg"

Camera2D :: struct {
	position: [2]f32,
	zoom:     f32,
	rotation: f32,
	viewport: Rect,
}

camera_create :: proc(logical_size: [2]int) -> Camera2D {
	w := f32(logical_size.x)
	h := f32(logical_size.y)

	return Camera2D{position = {w * 0.5, h * 0.5}, zoom = 1, rotation = 0, viewport = {0, 0, w, h}}
}

camera_get_view_projection :: proc(camera: Camera2D) -> matrix[4, 4]f32 {
	w := camera.viewport.w
	h := camera.viewport.h

	proj := linalg.matrix_ortho3d_f32(0, w, h, 0, -1, 1)
	view :=
		linalg.matrix4_translate_f32({w * 0.5, h * 0.5, 0}) *
		linalg.matrix4_rotate_f32(-camera.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32({camera.zoom, camera.zoom, 1}) *
		linalg.matrix4_translate_f32({-camera.position.x, -camera.position.y, 0})

	return proj * view
}

camera_screen_to_world :: proc(camera: Camera2D, screen_point: [2]f32) -> [2]f32 {
	p :=
		screen_point -
		{camera.viewport.x, camera.viewport.y} -
		{camera.viewport.w, camera.viewport.h} * 0.5

	c := math.cos(camera.rotation)
	s := math.sin(camera.rotation)

	p = {p.x * c - p.y * s, p.x * s + p.y * c} / camera.zoom
	return p + camera.position
}
