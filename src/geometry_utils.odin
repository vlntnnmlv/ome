package ome

// TODO: Get rid of
get_n_colors_rainbow :: proc(count: int) -> [dynamic]Color {
	colors := make([dynamic]Color, context.temp_allocator)
	for i in 0 ..< count {
		append(
			&colors,
			cast(Color)[4]int{int(i % 3 == 0), int((i + 2) % 3 == 0), int((i + 1) % 3 == 0), 1},
		)
	}

	return colors
}

get_n_colors_dupe :: proc(color: Color, count: int) -> [dynamic]Color {
	colors: [dynamic]Color = make([dynamic]Color, context.temp_allocator)
	for _ in 0 ..< count {
		append(&colors, color)
	}

	return colors
}

get_n_colors :: proc(color: Maybe(Color), count: int) -> [dynamic]Color {
	if real_color, ok := color.?; !ok {
		return get_n_colors_rainbow(count)
	} else {
		return get_n_colors_dupe(real_color, count)
	}
}

VERTICES_PER_QUAD :: 6
VERTICES_PER_NINE_SLICED_QUAD :: 9 * VERTICES_PER_QUAD
UNIT_RECT :: Rect{0, 0, 1, 1}

screen_to_world :: proc(logical_size: [2]i32, x: f32, y: f32) -> [2]f32 {
	return {2 * x / cast(f32)logical_size.x - 1, 1 - 2 * y / cast(f32)logical_size.y}
}

rect_split_to_grid :: proc(rect: Rect, offset: RectOffset) -> [9]Rect {
	xs := [4]f32{rect.x, rect.x + offset.left, rect.x + rect.w - offset.right, rect.x + rect.w}
	ys := [4]f32{rect.y, rect.y + offset.top, rect.y + rect.h - offset.bottom, rect.y + rect.h}

	cells: [9]Rect
	for row in 0 ..< 3 {
		for col in 0 ..< 3 {
			cells[row * 3 + col] = Rect {
				xs[col],
				ys[row],
				xs[col + 1] - xs[col],
				ys[row + 1] - ys[row],
			}
		}
	}
	return cells
}

rect_to_vertices_nine_slice :: proc(
	logical_size: [2]i32,
	rect: Rect,
	offset: RectOffset,
) -> [dynamic]Vertex {
	vertices := make([dynamic]Vertex, VERTICES_PER_NINE_SLICED_QUAD, context.temp_allocator)
	for cell, i in rect_split_to_grid(rect, offset) {
		rect_vertices := rect_to_vertices(logical_size, cell)
		copy(vertices[i * VERTICES_PER_QUAD:], rect_vertices[:])
	}
	return vertices
}

offset_to_uvs_nine_slice :: proc(offset: RectOffset, tw, th: f32) -> [dynamic]Uv {
	relative_offset := RectOffset {
		offset.left / tw,
		offset.right / tw,
		offset.top / th,
		offset.bottom / th,
	}

	uvs := make([dynamic]Uv, VERTICES_PER_NINE_SLICED_QUAD, context.temp_allocator)
	for cell, i in rect_split_to_grid({0, 0, 1, 1}, relative_offset) {
		rect_uvs := rect_to_uvs(cell)
		copy(uvs[i * VERTICES_PER_QUAD:], rect_uvs[:])
	}
	return uvs
}

rect_to_vertices :: proc(logical_size: [2]i32, rect: Rect) -> [dynamic]Vertex {
	vertices := make([dynamic]Vertex, VERTICES_PER_QUAD, context.temp_allocator)
	tl := point_to_vertex(logical_size, rect.x, rect.y)
	bl := point_to_vertex(logical_size, rect.x, rect.y + rect.h)
	br := point_to_vertex(logical_size, rect.x + rect.w, rect.y + rect.h)
	tr := point_to_vertex(logical_size, rect.x + rect.w, rect.y)

	vertices[0] = tl
	vertices[1] = bl
	vertices[2] = br
	vertices[3] = tl
	vertices[4] = br
	vertices[5] = tr

	return vertices
}

rect_to_uvs :: proc(rect: Rect) -> [dynamic]Uv {
	uvs := make([dynamic]Uv, VERTICES_PER_QUAD, context.temp_allocator)

	tl := Uv{rect.x, rect.y}
	bl := Uv{rect.x, rect.y + rect.h}
	br := Uv{rect.x + rect.w, rect.y + rect.h}
	tr := Uv{rect.x + rect.w, rect.y}

	uvs[0] = tl
	uvs[1] = bl
	uvs[2] = br
	uvs[3] = tl
	uvs[4] = br
	uvs[5] = tr

	return uvs
}

point_to_vertex :: proc {
	point_to_vertex_xy,
	point_to_vertex_array,
}

point_to_vertex_xy :: proc(logical_size: [2]i32, x: f32, y: f32) -> Vertex {
	tmp := screen_to_world(logical_size, x, y)
	return {tmp.x, tmp.y, 0, 1}
}

point_to_vertex_array :: proc(logical_size: [2]i32, point: [2]f32) -> Vertex {
	tmp := screen_to_world(logical_size, point.x, point.y)
	return {tmp.x, tmp.y, 0, 1}
}

points_to_vertices :: proc(logical_size: [2]i32, points: [][2]f32) -> [dynamic]Vertex {
	vertices := make([dynamic]Vertex, context.temp_allocator)

	for point in points {
		append(&vertices, point_to_vertex(logical_size, point.x, point.y))
	}

	return vertices
}
