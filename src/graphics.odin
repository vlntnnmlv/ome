package ome

import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

Vertex :: distinct [4]f32
Uv :: distinct [2]f32
Mode :: enum u32 {
	PRIMITIVE = 0,
	TEXT      = 1,
	TEXTURE   = 2,
}
TexID :: distinct u32

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
) {
	start := len(renderer.vertices.cpu)
	vertices := points_to_vertices(renderer.logical_size, points)

	vertices_count := len(points)
	gpu_buffer_append(&renderer.vertices, vertices[:])
	gpu_buffer_fill_zeros_n(&renderer.uvs, vertices_count)
	gpu_buffer_fill_n(&renderer.colors, color, vertices_count)
	gpu_buffer_fill_zeros_n(&renderer.modes, vertices_count)
	gpu_buffer_fill_zeros_n(&renderer.tex_ids, vertices_count)

	type: MTL.PrimitiveType = .LineStrip
	if fill do type = .Triangle
	graphics_append_render_call(renderer, type, start, vertices_count)
}

graphics_add_quad :: proc(renderer: ^Renderer, rect: Rect, color: Color) {
	start := len(renderer.vertices.cpu)
	vertices := rect_to_vertices(renderer.logical_size, rect)

	vertices_count := len(vertices)
	gpu_buffer_append(&renderer.vertices, vertices[:])
	gpu_buffer_fill_zeros_n(&renderer.uvs, vertices_count)
	gpu_buffer_fill_n(&renderer.colors, color, vertices_count)
	gpu_buffer_fill_zeros_n(&renderer.modes, vertices_count)
	gpu_buffer_fill_zeros_n(&renderer.tex_ids, vertices_count)

	graphics_append_render_call(renderer, .Triangle, start, vertices_count)
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
	total_vertices := make([dynamic]Vertex, 0, cap, context.temp_allocator)
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
		vertices := rect_to_vertices(renderer.logical_size, char_rect)

		uvs := [VERTICES_PER_QUAD]Uv {
			{quad.s0, quad.t0},
			{quad.s0, quad.t1},
			{quad.s1, quad.t1},
			{quad.s0, quad.t0},
			{quad.s1, quad.t1},
			{quad.s1, quad.t0},
		}

		append(&total_vertices, ..vertices[:])
		append(&total_uvs, ..uvs[:])
	}

	total_vertices_length := len(total_vertices)
	gpu_buffer_append(&renderer.vertices, total_vertices[:])
	gpu_buffer_append(&renderer.uvs, total_uvs[:])
	gpu_buffer_fill_n(&renderer.colors, color, total_vertices_length)
	gpu_buffer_fill_n(&renderer.modes, Mode.TEXT, total_vertices_length)
	gpu_buffer_fill_n(&renderer.tex_ids, TexID{}, total_vertices_length)

	graphics_append_render_call(renderer, .Triangle, start, total_vertices_length)
}

graphics_add_texture :: proc(
	renderer: ^Renderer,
	texture_handle: TextureHandle,
	rect: Rect,
	color: Color,
	slice_offset: Maybe(RectOffset) = nil,
) {
	start := len(renderer.vertices.cpu)
	positions: [dynamic]Vertex
	uvs: [dynamic]Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := renderer.texture_manager.textures[texture_handle]
		tw := cast(f32)tex->width()
		th := cast(f32)tex->height()

		positions = rect_to_vertices_nine_slice(renderer.logical_size, rect, rslice_offset)
		uvs = offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = rect_to_vertices(renderer.logical_size, rect)
		uvs = rect_to_uvs({0, 0, 1, 1})
	}

	vertices_count := len(positions)
	gpu_buffer_append(&renderer.vertices, positions[:])
	gpu_buffer_append(&renderer.uvs, uvs[:])
	gpu_buffer_fill_n(&renderer.colors, color, vertices_count)
	gpu_buffer_fill_n(&renderer.modes, Mode.TEXTURE, vertices_count)
	gpu_buffer_fill_n(&renderer.tex_ids, TexID(texture_handle), vertices_count)

	graphics_append_render_call(renderer, .Triangle, start, vertices_count)
}
