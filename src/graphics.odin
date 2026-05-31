package ome

import "core:slice"

import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

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
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	start := len(renderer.vertices.cpu)
	vertices_count := len(points)

	vertices := points_to_vertices(renderer.logical_size, points)
	colors := get_n_colors(color, vertices_count)
	uvs := make([]Uv, vertices_count, context.temp_allocator)
	modes := make([]Mode, vertices_count, context.temp_allocator)
	tex_ids := make([]TexID, vertices_count, context.temp_allocator)

	gpu_buffer_append(&renderer.vertices, vertices[:])
	gpu_buffer_append(&renderer.colors, colors[:])
	gpu_buffer_append(&renderer.uvs, uvs[:])
	gpu_buffer_append(&renderer.modes, modes[:])
	gpu_buffer_append(&renderer.tex_ids, tex_ids[:])

	type: MTL.PrimitiveType = .LineStrip
	if fill do type = .Triangle
	graphics_append_render_call(renderer, type, start, vertices_count)
}

graphics_add_quad :: proc(renderer: ^Renderer, rect: Rect, color: Maybe(Color) = nil) {
	start := len(renderer.vertices.cpu)
	vertices := rect_to_vertices(renderer.logical_size, rect)
	vertices_count := len(vertices)

	colors := get_n_colors(color, vertices_count)
	uvs := make([dynamic]Uv, vertices_count, context.temp_allocator)
	modes := make([dynamic]Mode, vertices_count, context.temp_allocator)
	tex_ids := make([dynamic]TexID, vertices_count, context.temp_allocator)

	gpu_buffer_append(&renderer.vertices, vertices[:])
	gpu_buffer_append(&renderer.colors, colors[:])
	gpu_buffer_append(&renderer.uvs, uvs[:])
	gpu_buffer_append(&renderer.modes, modes[:])
	gpu_buffer_append(&renderer.tex_ids, tex_ids[:])

	graphics_append_render_call(renderer, .Triangle, start, vertices_count)
}

graphics_add_text :: proc(
	renderer: ^Renderer,
	text: string,
	font_size: f32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	real_font_size := text_fit(renderer, text, font_size, rect)
	assets_validate_font_size(renderer, real_font_size)

	x := rect.x
	y := rect.y

	for char in text {
		if char < CharAtStart || char > CharAtStart + CharAmount do continue

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

		start := len(renderer.vertices.cpu)
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
		colors := get_n_colors(color, VERTICES_PER_QUAD)
		modes: [VERTICES_PER_QUAD]Mode = 1
		tex_ids := [VERTICES_PER_QUAD]TexID{}

		gpu_buffer_append(&renderer.vertices, vertices[:])
		gpu_buffer_append(&renderer.colors, colors[:])
		gpu_buffer_append(&renderer.uvs, uvs[:])
		gpu_buffer_append(&renderer.modes, modes[:])
		gpu_buffer_append(&renderer.tex_ids, tex_ids[:])

		graphics_append_render_call(renderer, .Triangle, start, VERTICES_PER_QUAD)
	}
}

graphics_add_texture :: proc(
	renderer: ^Renderer,
	texture_handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
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

	colors := get_n_colors(color, vertices_count)

	modes := make([dynamic]Mode, vertices_count, context.temp_allocator)
	slice.fill(modes[:], 2)

	tex_ids := make([dynamic]TexID, vertices_count, context.temp_allocator)
	slice.fill(tex_ids[:], TexID(texture_handle))

	gpu_buffer_append(&renderer.vertices, positions[:])
	gpu_buffer_append(&renderer.colors, colors[:])
	gpu_buffer_append(&renderer.uvs, uvs[:])
	gpu_buffer_append(&renderer.modes, modes[:])
	gpu_buffer_append(&renderer.tex_ids, tex_ids[:])

	graphics_append_render_call(renderer, .Triangle, start, vertices_count)
}
