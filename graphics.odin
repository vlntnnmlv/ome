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

graphics_add_text :: proc(text: string, x: f32, y: f32, color: Color) {
	// TODO: Use new API and add fitting
	cx := x
	cy := cast(f32)app.height - y

	for ch in text {
		if ch < 32 || ch >= 128 do continue

		q: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font_new.char_data[0],
			FONT_ATLAS_SIZE,
			FONT_ATLAS_SIZE,
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
		col := get_n_colors_dupe(color, 6)
		mode := [6]Mode{1, 1, 1, 1, 1, 1}

		start := len(app.positions.cpu)
		gpu_buffer_append(&app.positions, pos[:])
		gpu_buffer_append(&app.colors, col[:])
		gpu_buffer_append(&app.uvs, uvs[:])
		gpu_buffer_append(&app.modes, mode[:])

		append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = 6})
	}
}
