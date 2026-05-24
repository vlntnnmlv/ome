package ome

render_line :: proc(start: [2]f32, end: [2]f32, color: Maybe(Color) = nil) {
	graphics_add_points({start, end}, color)
}

render_segments :: proc(points: [][2]f32, color: Maybe(Color) = nil, fill: bool = false) {
	graphics_add_points(points, color, fill)
}

render_rect :: proc(rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(rect, color)
}

render_text :: proc(text: string, font_size: f32, rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_text(text, font_size, rect, color)
}

render_texture :: proc(
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = Color{1, 1, 1, 1},
) {
	graphics_add_texture(handle, rect, color)
}

render_mesh :: proc(_: any) {
	/* TODO: Add mesh rendering */
}
