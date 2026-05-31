package ome

import MTL "vendor:darwin/Metal"

Renderer :: struct {
	device:          ^MTL.Device,
	command_q:       ^MTL.CommandQueue,
	pipeline_state:  ^MTL.RenderPipelineState,
	render_calls:    [dynamic]RenderCall,
	texture_manager: ^TextureManager,
	font:            Font,
	logical_size:    [2]i32,
	vertices:        GPUBuffer(Vertex),
	colors:          GPUBuffer(Color),
	uvs:             GPUBuffer(Uv),
	tex_ids:         GPUBuffer(TexID),
	modes:           GPUBuffer(Mode),
}

render_line :: proc(renderer: ^Renderer, start: [2]f32, end: [2]f32, color: Maybe(Color) = nil) {
	graphics_add_points(renderer, {start, end}, color)
}

render_segments :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	graphics_add_points(renderer, points, color, fill)
}

render_rect :: proc(renderer: ^Renderer, rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(renderer, rect, color)
}

render_text :: proc(
	renderer: ^Renderer,
	text: string,
	font_size: f32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	graphics_add_text(renderer, text, font_size, rect, color)
}

render_texture :: proc(
	renderer: ^Renderer,
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	graphics_add_texture(renderer, handle, rect, color, slice_offset)
}
