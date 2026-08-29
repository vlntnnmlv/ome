package ome


import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

Mode :: enum u32 {
	Primitive = 0,
	Text      = 1,
	Texture   = 2,
}

Position :: distinct [4]f32
Uv :: distinct [2]f32
TexID :: distinct u32

Vertex2D :: struct {
	position: Position,
	uv:       Uv,
	color:    [4]f32,
	mode:     Mode,
	tex_id:   TexID,
}

graphics_append_render_call :: proc(
	renderer: ^Renderer,
	type: MTL.PrimitiveType,
	start, count: int,
) {
	mergable := type == .Point || type == .Line || type == .Triangle
	n := len(renderer.render_calls)
	if n > 0 && mergable && renderer.render_calls[n - 1].type == type {
		renderer.render_calls[n - 1].count += count
	} else {
		append(&renderer.render_calls, RenderCall{type = type, start = start, count = count})
	}
}

graphics_add_points :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: Color,
	fill: bool = false,
	thickness: int = 1,
) {
	start := len(renderer.vertices.cpu)
	positions: [dynamic]Position

	if thickness > 1 {
		positions = points_to_vertices_positions_thickness(
			renderer.logical_size,
			points,
			thickness,
		)
	} else {
		positions = points_to_vertices_positions(renderer.logical_size, points)
	}

	vertices: []Vertex2D = vertices_positions_to_vertices(positions[:], color)
	gpu_buffer_append(&renderer.vertices, vertices[:])

	type: MTL.PrimitiveType = .LineStrip
	if fill || thickness > 1 do type = .Triangle
	graphics_append_render_call(renderer, type, start, len(vertices))
}

graphics_add_quad :: proc(renderer: ^Renderer, rect: Rect, color: Color) {
	start := len(renderer.vertices.cpu)
	positions := rect_to_vertices_positions(renderer.logical_size, rect)

	vertices := vertices_positions_to_vertices(positions[:], color)

	gpu_buffer_append(&renderer.vertices, vertices)

	graphics_append_render_call(renderer, .Triangle, start, len(vertices))
}

graphics_add_text :: proc(
	renderer: ^Renderer,
	text: string,
	font_size: u32,
	rect: Rect,
	color: Color,
) {
	real_font_size := text_fit(renderer, text, font_size, rect)
	assets_validate_font_size(renderer, real_font_size)

	x := rect.x
	y := rect.y

	cap := len(text) * VERTICES_PER_QUAD
	total_positions := make([dynamic]Position, 0, cap, context.temp_allocator)
	total_uvs := make([dynamic]Uv, 0, cap, context.temp_allocator)

	start := len(renderer.vertices.cpu)
	it := StringPrintableIterator{text, 0}
	for char in iterate_printable(&it) {
		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&renderer.font.char_data[real_font_size][0],
			renderer.font.bitmap_size,
			renderer.font.bitmap_size,
			cast(i32)char - 32,
			&x,
			&y,
			&quad,
			true,
		)

		char_rect := Rect{quad.x0, quad.y0, quad.x1 - quad.x0, quad.y1 - quad.y0}
		vertices := rect_to_vertices_positions(renderer.logical_size, char_rect)

		uvs := [VERTICES_PER_QUAD]Uv {
			{quad.s0, quad.t0},
			{quad.s0, quad.t1},
			{quad.s1, quad.t1},
			{quad.s0, quad.t0},
			{quad.s1, quad.t1},
			{quad.s1, quad.t0},
		}

		append(&total_positions, ..vertices[:])
		append(&total_uvs, ..uvs[:])
	}

	vertices := vertices_positions_and_uvs_to_vertices(
		total_positions[:],
		total_uvs[:],
		color,
		Mode.Text,
	)

	gpu_buffer_append(&renderer.vertices, vertices)

	graphics_append_render_call(renderer, .Triangle, start, len(vertices))
}

// graphics_add_sprite :: proc(
// 	renderer: ^Renderer,
// 	atlas_handle: TextureHandle,
// 	sprite: [4]Uv,
// 	rect: Rect,
// 	color: Color,
// 	slice_offset: Maybe(RectOffset) = nil,
// )
// {

// }

graphics_add_texture :: proc(
	renderer: ^Renderer,
	texture_handle: TextureHandle,
	positions: []Position,
	uvs: []Uv,
	color: Color,
	slice_offset: Maybe(RectOffset) = nil,
) {
	start := len(renderer.vertices.cpu)

	vertices := vertices_positions_and_uvs_to_vertices(
		positions[:],
		uvs[:],
		color,
		Mode.Texture,
		TexID(texture_handle),
	)

	gpu_buffer_append(&renderer.vertices, vertices)

	graphics_append_render_call(renderer, .Triangle, start, len(vertices))
}
