package omerender

import "core:math/linalg"

import "ome:core"
import "ome:gpu"

VERTICES_PER_QUAD :: 6
VERTICES_PER_NINE_SLICED_QUAD :: 9 * VERTICES_PER_QUAD

rect_to_vertices_positions :: proc(rect: core.Rect) -> [VERTICES_PER_QUAD]gpu.Position {
	vertices := [VERTICES_PER_QUAD]gpu.Position{}
	tl := point_to_vertex(rect.x, rect.y)
	bl := point_to_vertex(rect.x, rect.y + rect.h)
	br := point_to_vertex(rect.x + rect.w, rect.y + rect.h)
	tr := point_to_vertex(rect.x + rect.w, rect.y)

	vertices[0] = tl
	vertices[1] = bl
	vertices[2] = br
	vertices[3] = tl
	vertices[4] = br
	vertices[5] = tr

	return vertices
}

rect_to_vertices_positions_nine_slice :: proc(
	rect: core.Rect,
	rect_offset: core.RectOffset,
) -> [VERTICES_PER_NINE_SLICED_QUAD]gpu.Position {
	vertices := [VERTICES_PER_NINE_SLICED_QUAD]gpu.Position{}
	for cell, i in core.rect_split_to_grid(rect, rect_offset) {
		rect_vertices := rect_to_vertices_positions(cell)
		copy(vertices[i * VERTICES_PER_QUAD:], rect_vertices[:])
	}
	return vertices
}

rect_to_uvs :: proc(rect: core.Rect) -> [VERTICES_PER_QUAD]gpu.UV {
	tl := gpu.UV{rect.x, rect.y}
	bl := gpu.UV{rect.x, rect.y + rect.h}
	br := gpu.UV{rect.x + rect.w, rect.y + rect.h}
	tr := gpu.UV{rect.x + rect.w, rect.y}

	return {tl, bl, br, tl, br, tr}
}

rect_offset_to_uvs_nine_slice :: proc(
	offset: core.RectOffset,
	width, height: f32,
) -> [VERTICES_PER_NINE_SLICED_QUAD]gpu.UV {
	relative_offset := core.RectOffset {
		offset.left / width,
		offset.right / width,
		offset.top / height,
		offset.bottom / height,
	}

	uvs := [VERTICES_PER_NINE_SLICED_QUAD]gpu.UV{}
	for cell, i in core.rect_split_to_grid(core.UNIT_RECT, relative_offset) {
		cell_uvs := rect_to_uvs(cell)
		copy(uvs[i * VERTICES_PER_QUAD:], cell_uvs[:])
	}
	return uvs
}

rect_offset_to_uvs_nine_slice_atlas :: proc(
	offset: core.RectOffset,
	uv_rect: core.Rect,
	atlas_size: [2]f32,
) -> [VERTICES_PER_NINE_SLICED_QUAD]gpu.UV {
	relative_offset := core.RectOffset {
		offset.left / atlas_size.x,
		offset.right / atlas_size.x,
		offset.top / atlas_size.y,
		offset.bottom / atlas_size.y,
	}

	uvs := [VERTICES_PER_NINE_SLICED_QUAD]gpu.UV{}
	for cell, i in core.rect_split_to_grid(uv_rect, relative_offset) {
		rect_uvs := rect_to_uvs(cell)
		copy(uvs[i * VERTICES_PER_QUAD:], rect_uvs[:])
	}
	return uvs
}

// ---
uvs_mirror :: proc(uvs: []gpu.UV, bounds: core.Rect, flip: core.Flip) {
	c := gpu.UV{2 * bounds.x + bounds.w, 2 * bounds.y + bounds.h}
	for &uv in uvs {
		if .X in flip {uv.x = c.x - uv.x}
		if .Y in flip {uv.y = c.y - uv.y}
	}
}

// ---
point_to_vertex :: proc {
	point_to_vertex_xy,
	point_to_vertex_array,
}

@(private = "file")
point_to_vertex_xy :: proc(x: f32, y: f32) -> gpu.Position {
	return {x, y, 0, 1}
}

@(private = "file")
point_to_vertex_array :: proc(point: [2]f32) -> gpu.Position {
	return {point.x, point.y, 0, 1}
}

points_to_vertices_positions :: proc(points: [][2]f32) -> [dynamic]gpu.Position {
	vertices := make([dynamic]gpu.Position, context.temp_allocator)

	for point in points {
		append(&vertices, point_to_vertex(point))
	}

	return vertices
}

points_to_vertices_positions_thickness :: proc(
	points: [][2]f32,
	thickness: int,
) -> [dynamic]gpu.Position {
	vertices := make([dynamic]gpu.Position, context.temp_allocator)
	half := f32(thickness) * 0.5

	for i in 0 ..< len(points) - 1 {
		point_a := points[i]
		point_b := points[i + 1]

		dir := linalg.vector_normalize0(point_b - point_a)
		perp := [2]f32{-dir.y, dir.x} * half

		p0 := point_to_vertex(point_a + perp)
		p1 := point_to_vertex(point_a - perp)
		p2 := point_to_vertex(point_b - perp)
		p3 := point_to_vertex(point_b + perp)

		append(&vertices, p0, p1, p2, p0, p2, p3)
	}

	return vertices
}

// // ---
// vertices_positions_to_vertices :: proc(
// 	positions: []gpu.Position,
// 	color: core.Color,
// 	mode: gpu.Mode = .Primitive,
// 	texture_id: gpu.TextureID = {},
// ) -> []gpu.Vertex2D {
// 	vertices := make([dynamic]gpu.Vertex2D, len(positions), context.temp_allocator)
// 	lcolor := core.color_to_linear32(color)
// 	for p, i in positions {
// 		vertices[i] = gpu.Vertex2D {
// 			position   = p,
// 			color      = lcolor,
// 			mode       = mode,
// 			texture_id = texture_id,
// 		}
// 	}

// 	return vertices[:]
// }

vertices_write :: proc(
	destination: []gpu.Vertex2D,
	positions: []gpu.Position,
	uvs: []gpu.UV,
	color: core.Color,
	mode: gpu.Mode = .Primitive,
	texture_id: gpu.TextureID = {},
) {
	assert(len(destination) == len(positions))
	assert(len(uvs) == 0 || len(uvs) == len(positions))

	lcolor := core.color_to_linear32(color)
	for &v, i in destination {
		v = gpu.Vertex2D {
			position   = positions[i],
			color      = lcolor,
			mode       = mode,
			texture_id = texture_id,
		}
	}

	for uv, i in uvs {
		destination[i].uv = uv
	}
}

// vertices_positions_and_uvs_to_vertices :: proc(
// 	positions: []gpu.Position,
// 	uvs: []gpu.UV,
// 	color: core.Color,
// 	mode: gpu.Mode = .Primitive,
// 	texture_id: gpu.TextureID = {},
// ) -> []gpu.Vertex2D {
// 	vertices := make([dynamic]gpu.Vertex2D, len(positions), context.temp_allocator)
// 	lcolor := core.color_to_linear32(color)
// 	for p, i in positions {
// 		vertices[i] = gpu.Vertex2D {
// 			position   = p,
// 			uv         = uvs[i],
// 			color      = lcolor,
// 			mode       = mode,
// 			texture_id = texture_id,
// 		}
// 	}

// 	return vertices[:]
// }
