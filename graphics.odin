package ome

import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

graphics_add_points :: proc(points: [][2]f32, color: Maybe(Color) = nil, fill: bool = false) {
	start := len(app.positions.cpu)
	points_count := len(points)

	positions_data := points2vertices(points)
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

	append(&app.render_calls, RenderCall{type = type, start = start, count = points_count})
}

graphics_add_quad :: proc(rect: Rect, color: Maybe(Color) = nil) {
	start := len(app.positions.cpu)
	positions_data := rect2vertices(rect)
	points_count := len(positions_data)
	gpu_buffer_append(&app.positions, positions_data[:])

	colors_data := get_n_colors(color, points_count)
	gpu_buffer_append(&app.colors, colors_data[:])

	zero_uvs := [6]Uv{}
	gpu_buffer_append(&app.uvs, zero_uvs[:])

	zero_modes := [6]Mode{}
	gpu_buffer_append(&app.modes, zero_modes[:])

	append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = points_count})
}

measure_text :: proc(text: string, font_size: f32) -> [2]f32 {
	r_font_size := asset_get_or_update_font_size(font_size)

	x, y, max_x: f32 = 0, 0, 0
	for ch in text {
		if ch < CharAtStart || ch > CharAtStart + CharAmount do continue

		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font.char_data_new[r_font_size][0],
			app.font.bitmap_size,
			app.font.bitmap_size,
			cast(i32)ch - 32,
			&x,
			&y,
			&quad,
			true,
		)
		max_x = max(x, max_x)
	}

	return {max_x, r_font_size}
}

fit_text :: proc(text: string, font_size: f32, rect: Rect) -> f32 {
	size := measure_text(text, font_size)
	scale_x := rect.w / size.x
	scale_y := rect.h / size.y
	scale := min(scale_x, scale_y)
	return font_size * min(scale, 1)
}

graphics_add_text :: proc(text: string, font_size: f32, rect: Rect, color: Maybe(Color) = nil) {
	r_font_size := asset_get_or_update_font_size(fit_text(text, font_size, rect))

	cx := rect.x
	cy := cast(f32)app.height - rect.y

	for ch in text {
		if ch < 32 || ch >= 128 do continue

		q: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font.char_data_new[r_font_size][0],
			app.font.bitmap_size,
			app.font.bitmap_size,
			cast(i32)ch - 32,
			&cx,
			&cy,
			&q,
			true,
		)

		pos := [6]Vertex {
			point2vertex(q.x0, cast(f32)app.height - q.y0),
			point2vertex(q.x0, cast(f32)app.height - q.y1),
			point2vertex(q.x1, cast(f32)app.height - q.y1),
			point2vertex(q.x0, cast(f32)app.height - q.y0),
			point2vertex(q.x1, cast(f32)app.height - q.y1),
			point2vertex(q.x1, cast(f32)app.height - q.y0),
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

		append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = 6})
	}
}
