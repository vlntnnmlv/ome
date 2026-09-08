package ome

import "core:math"
import "core:math/linalg"

Camera :: union {
	Camera3D,
	Camera2D,
}

Camera3D :: struct {
	position: [3]f32,
	target:   [3]f32,
	up:       [3]f32,
	fov_y:    f32,
	near:     f32,
	far:      f32,
	viewport: Rect,
}

Camera2D :: struct {
	position: [2]f32,
	zoom:     f32,
	rotation: f32,
	viewport: Rect,
}

camera2d_create :: proc(logical_size: [2]int) -> Camera2D {
	w := f32(logical_size.x)
	h := f32(logical_size.y)

	return Camera2D{position = {w * 0.5, h * 0.5}, zoom = 1, rotation = 0, viewport = {0, 0, w, h}}
}

camera_get_view_projection :: proc(camera: Camera) -> matrix[4, 4]f32 {
	switch c in camera {
	case Camera2D:
		return camera2d_get_view_projection(c)
	case Camera3D:
		return camera3d_get_view_projection(c)
	}
	return 1
}

@(private = "file")
camera2d_get_view_projection :: proc(camera: Camera2D) -> matrix[4, 4]f32 {
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

@(private = "file")
camera3d_get_view_projection :: proc(camera: Camera3D) -> matrix[4, 4]f32 {
	f := linalg.normalize(camera.target - camera.position)
	s := linalg.normalize(linalg.cross(f, camera.up))
	u := linalg.cross(s, f)
	e := camera.position

	view := matrix[4, 4]f32{
		s.x, s.y, s.z, -linalg.dot(s, e),
		u.x, u.y, u.z, -linalg.dot(u, e),
		-f.x, -f.y, -f.z, linalg.dot(f, e),
		0, 0, 0, 1,
	}

	t := 1 / math.tan(camera.fov_y * 0.5)
	a := camera.viewport.w / camera.viewport.h
	n := camera.near
	fa := camera.far

	proj := matrix[4, 4]f32{
		t / a, 0, 0, 0,
		0, t, 0, 0,
		0, 0, fa / (n - fa), fa * n / (n - fa),
		0, 0, -1, 0,
	}

	return proj * view
}

camera2d_screen_to_world :: proc(camera: Camera2D, screen_point: [2]f32) -> [2]f32 {
	p :=
		screen_point -
		{camera.viewport.x, camera.viewport.y} -
		{camera.viewport.w, camera.viewport.h} * 0.5

	c := math.cos(camera.rotation)
	s := math.sin(camera.rotation)

	p = {p.x * c - p.y * s, p.x * s + p.y * c} / camera.zoom
	return p + camera.position
}
