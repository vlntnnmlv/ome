package ome

render_line :: proc(app: ^App, start: [2]f32, end: [2]f32, color: Maybe(Color) = nil) {
	graphics_add_points(app, {start, end}, color)
}

render_segments :: proc(
	app: ^App,
	points: [][2]f32,
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	graphics_add_points(app, points, color, fill)
}

render_rect :: proc(app: ^App, rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(app, rect, color)
}

render_text :: proc(
	app: ^App,
	text: string,
	font_size: f32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	graphics_add_text(app, text, font_size, rect, color)
}

render_texture :: proc(
	app: ^App,
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	graphics_add_texture(app, handle, rect, color, slice_offset)
}
