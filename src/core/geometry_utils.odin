package ome

import "core:math/linalg"
VERTICES_PER_QUAD :: 6
VERTICES_PER_NINE_SLICED_QUAD :: 9 * VERTICES_PER_QUAD
UNIT_RECT :: Rect{0, 0, 1, 1}

screen_to_world :: proc(logical_size: [2]int, x: f32, y: f32) -> [2]f32 {
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
	logical_size: [2]int,
	rect: Rect,
	offset: RectOffset,
) -> [dynamic]Position {
	vertices := make([dynamic]Position, VERTICES_PER_NINE_SLICED_QUAD, context.temp_allocator)
	for cell, i in rect_split_to_grid(rect, offset) {
		rect_vertices := rect_to_vertices_positions(logical_size, cell)
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

rect_to_vertices_positions :: proc(logical_size: [2]int, rect: Rect) -> [dynamic]Position {
	vertices := make([dynamic]Position, VERTICES_PER_QUAD, context.temp_allocator)
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

point_to_vertex_xy :: proc(logical_size: [2]int, x: f32, y: f32) -> Position {
	tmp := screen_to_world(logical_size, x, y)
	return {tmp.x, tmp.y, 0, 1}
}

point_to_vertex_array :: proc(logical_size: [2]int, point: [2]f32) -> Position {
	tmp := screen_to_world(logical_size, point.x, point.y)
	return {tmp.x, tmp.y, 0, 1}
}

points_to_vertices_positions :: proc(logical_size: [2]int, points: [][2]f32) -> [dynamic]Position {
	vertices := make([dynamic]Position, context.temp_allocator)

	for point in points {
		append(&vertices, point_to_vertex(logical_size, point))
	}

	return vertices
}

vertices_positions_to_vertices :: proc(
	positions: []Position,
	color: Color,
	mode: Mode = Mode{},
	tex_id: TexID = TexID{},
) -> []Vertex2D {
	vertices := make([dynamic]Vertex2D, len(positions), context.temp_allocator)
	for p, i in positions {
		vertices[i] = Vertex2D {
			position = p,
			color    = color_to_linear32(color),
			mode     = mode,
			tex_id   = tex_id,
		}
	}

	return vertices[:]
}

vertices_positions_and_uvs_to_vertices :: proc(
	positions: []Position,
	uvs: []Uv,
	color: Color,
	mode: Mode = Mode{},
	tex_id: TexID = TexID{},
) -> []Vertex2D {
	vertices := make([dynamic]Vertex2D, len(positions), context.temp_allocator)
	for p, i in positions {
		vertices[i] = Vertex2D {
			position = p,
			uv       = uvs[i],
			color    = color_to_linear32(color),
			mode     = mode,
			tex_id   = tex_id,
		}
	}

	return vertices[:]
}

points_to_vertices_positions_thickness :: proc(
	logical_size: [2]int,
	points: [][2]f32,
	thickness: int,
) -> [dynamic]Position {
	vertices := make([dynamic]Position, context.temp_allocator)
	half := cast(f32)thickness * 0.5

	for i in 0 ..< len(points) - 1 {
		point_a := points[i]
		point_b := points[i + 1]

		dir := linalg.vector_normalize0(point_b - point_a)
		perp := [2]f32{-dir.y, dir.x} * half

		p0 := point_to_vertex(logical_size, point_a + perp * cast(f32)thickness / 2)
		p1 := point_to_vertex(logical_size, point_a - perp * cast(f32)thickness / 2)
		p2 := point_to_vertex(logical_size, point_b - perp * cast(f32)thickness / 2)
		p3 := point_to_vertex(logical_size, point_b + perp * cast(f32)thickness / 2)

		append(&vertices, p0, p1, p2, p0, p2, p3)
	}

	return vertices
}
