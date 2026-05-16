package ome

render_line :: proc(x: [2]f32, y: [2]f32, color: Maybe(Color) = nil) {
	graphics_add_points({x, y}, color)
}

render_segments :: proc(points: [][2]f32, color: Maybe(Color) = nil, fill: bool = false) {
	graphics_add_points(points, color, fill)
}

render_rect :: proc(rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(rect, color)
}

render_text :: proc(text: string, x: f32, y: f32) {
	graphics_add_text(text, x, y, {0, 0, 0, 1})
}

render_texture :: proc(
	rect: Rect,
	_: any,
	/* TODO: Add texture struct */
) {
}

render_mesh :: proc(
	_: any,
	/* TODO: Add mesh struc*/
) {

}
