package ome

import "core:slice"

import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

graphics_add_points :: proc(points: [][2]f32, color: Maybe(Color) = nil, fill: bool = false) {
	start := len(app.positions.cpu)
	points_count := len(points)

	positions_data := points_to_vertices(points)
	gpu_buffer_append(&app.positions, positions_data[:])

	colors_data := get_n_colors(color, points_count)
	gpu_buffer_append(&app.colors, colors_data[:])

	type: MTL.PrimitiveType = .Point
	if fill {
		type = .Triangle
	} else {
		type = .LineStrip
	}

	zero_uvs := make([]Uv, points_count, context.temp_allocator)
	gpu_buffer_append(&app.uvs, zero_uvs[:])

	zero_modes := make([]Mode, points_count, context.temp_allocator)
	gpu_buffer_append(&app.modes, zero_modes[:])

	zero_tex_ids := make([]TexID, points_count, context.temp_allocator)
	gpu_buffer_append(&app.tex_ids, zero_tex_ids[:])

	append(&app.render_calls, RenderCall{type = type, start = start, count = points_count})
}

graphics_add_quad :: proc(rect: Rect, color: Maybe(Color) = nil) {
	start := len(app.positions.cpu)
	positions_data := rect_to_vertices(rect)
	points_count := len(positions_data)
	gpu_buffer_append(&app.positions, positions_data[:])

	colors_data := get_n_colors(color, points_count)
	gpu_buffer_append(&app.colors, colors_data[:])

	zero_uvs := [6]Uv{}
	gpu_buffer_append(&app.uvs, zero_uvs[:])

	zero_modes := [6]Mode{}
	gpu_buffer_append(&app.modes, zero_modes[:])

	zero_tex_ids := [6]TexID{}
	gpu_buffer_append(&app.tex_ids, zero_tex_ids[:])

	append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = points_count})
}

graphics_add_text :: proc(text: string, font_size: f32, rect: Rect, color: Maybe(Color) = nil) {
	real_font_size := text_fit(text, font_size, rect)
	assets_validate_font_size(real_font_size)

	cx := rect.x
	cy := rect.y

	for ch in text {
		if ch < CharAtStart || ch > CharAtStart + CharAmount do continue

		q: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font.char_data_new[real_font_size][0],
			app.font.bitmap_size,
			app.font.bitmap_size,
			cast(i32)ch - 32,
			&cx,
			&cy,
			&q,
			true,
		)

		pos := [6]Vertex {
			point_to_vertex(q.x0, q.y0),
			point_to_vertex(q.x0, q.y1),
			point_to_vertex(q.x1, q.y1),
			point_to_vertex(q.x0, q.y0),
			point_to_vertex(q.x1, q.y1),
			point_to_vertex(q.x1, q.y0),
		}

		uvs := [6]Uv {
			{q.s0, q.t0},
			{q.s0, q.t1},
			{q.s1, q.t1},
			{q.s0, q.t0},
			{q.s1, q.t1},
			{q.s1, q.t0},
		}
		col := get_n_colors(color, 6)
		mode := [6]Mode{1, 1, 1, 1, 1, 1}

		start := len(app.positions.cpu)
		gpu_buffer_append(&app.positions, pos[:])
		gpu_buffer_append(&app.colors, col[:])
		gpu_buffer_append(&app.uvs, uvs[:])
		gpu_buffer_append(&app.modes, mode[:])

		zero_tex_ids := [6]TexID{}
		gpu_buffer_append(&app.tex_ids, zero_tex_ids[:])

		append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = 6})
	}
}

graphics_add_texture :: proc(
	texture_handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	positions: [dynamic]Vertex
	uvs: [dynamic]Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := app.texture_manager.textures[texture_handle]
		tw := cast(f32)tex->width()
		th := cast(f32)tex->height()

		positions = rect_to_vertices_nine_slice(rect, rslice_offset)
		uvs = offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = rect_to_vertices(rect)
		uvs = rect_to_uvs({0, 0, 1, 1})
	}

	vertices_count := len(positions)
	colors := get_n_colors(color, vertices_count)
	modes := make([dynamic]Mode, vertices_count, context.temp_allocator)
	slice.fill(modes[:], 2)

	tex_ids := make([dynamic]TexID, vertices_count, context.temp_allocator)
	slice.fill(tex_ids[:], TexID(texture_handle))

	start := len(app.positions.cpu)
	gpu_buffer_append(&app.positions, positions[:])
	gpu_buffer_append(&app.colors, colors)
	gpu_buffer_append(&app.uvs, uvs[:])
	gpu_buffer_append(&app.modes, modes[:])
	gpu_buffer_append(&app.tex_ids, tex_ids[:])

	append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = vertices_count})
}
