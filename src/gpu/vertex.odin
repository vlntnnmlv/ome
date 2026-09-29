package omegpu

import "core:math/linalg"
import "core:mem"

import "ome:core"

VERTICES_PER_QUAD :: 6
VERTICES_PER_NINE_SLICED_QUAD :: 9 * VERTICES_PER_QUAD

Mode :: enum u32 {
	Primitive = 0,
	Text      = 1,
	Texture   = 2,
}

Position :: distinct [4]f32
UV :: distinct [2]f32
TextureID :: distinct u32

Vertex2D :: struct {
	position:   Position,
	uv:         UV,
	color:      [4]f32,
	mode:       Mode,
	texture_id: TextureID,
}

// --- Rect to Vertices ---

rect_to_vertices_positions_nine_slice :: proc(
	rect: core.Rect,
	rect_offset: core.RectOffset,
) -> [dynamic]Position {
	vertices := make([dynamic]Position, VERTICES_PER_NINE_SLICED_QUAD, context.temp_allocator)
	for cell, i in core.rect_split_to_grid(rect, rect_offset) {
		rect_vertices := rect_to_vertices_positions(cell)
		copy(vertices[i * VERTICES_PER_QUAD:], rect_vertices[:])
	}
	return vertices
}

rect_to_vertices_positions :: proc(rect: core.Rect) -> [dynamic]Position {
	vertices := make([dynamic]Position, VERTICES_PER_QUAD, context.temp_allocator)
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

// --- Rect to UVs ---

rect_to_uvs :: proc(rect: core.Rect) -> [dynamic]UV {
	uvs := make([dynamic]UV, VERTICES_PER_QUAD, context.temp_allocator)

	tl := UV{rect.x, rect.y}
	bl := UV{rect.x, rect.y + rect.h}
	br := UV{rect.x + rect.w, rect.y + rect.h}
	tr := UV{rect.x + rect.w, rect.y}

	uvs[0] = tl
	uvs[1] = bl
	uvs[2] = br
	uvs[3] = tl
	uvs[4] = br
	uvs[5] = tr

	return uvs
}

rect_to_uvs_atlas :: proc(
	rect: core.Rect,
	atlas_size: [2]f32,
	allocator: mem.Allocator = context.temp_allocator,
) -> [dynamic]UV {
	uvs := make([dynamic]UV, VERTICES_PER_QUAD, allocator)

	tl := UV{rect.x / atlas_size.x, rect.y / atlas_size.y}
	bl := UV{rect.x / atlas_size.x, (rect.y + rect.h) / atlas_size.y}
	br := UV{(rect.x + rect.w) / atlas_size.x, (rect.y + rect.h) / atlas_size.y}
	tr := UV{(rect.x + rect.w) / atlas_size.x, rect.y / atlas_size.y}

	uvs[0] = tl
	uvs[1] = bl
	uvs[2] = br
	uvs[3] = tl
	uvs[4] = br
	uvs[5] = tr

	return uvs
}

rect_offset_to_uvs_nine_slice :: proc(offset: core.RectOffset, width, height: f32) -> [dynamic]UV {
	relative_offset := core.RectOffset {
		offset.left / width,
		offset.right / width,
		offset.top / height,
		offset.bottom / height,
	}

	uvs := make([dynamic]UV, VERTICES_PER_NINE_SLICED_QUAD, context.temp_allocator)
	for cell, i in core.rect_split_to_grid(core.UNIT_RECT, relative_offset) {
		rect_uvs := rect_to_uvs(cell)
		copy(uvs[i * VERTICES_PER_QUAD:], rect_uvs[:])
	}
	return uvs
}

rect_offset_to_uvs_nine_slice_atlas :: proc(
	offset: core.RectOffset,
	uv_rect: core.Rect,
	atlas_size: [2]f32,
	allocator: mem.Allocator = context.temp_allocator,
) -> [dynamic]UV {
	relative_offset := core.RectOffset {
		offset.left / atlas_size.x,
		offset.right / atlas_size.x,
		offset.top / atlas_size.y,
		offset.bottom / atlas_size.y,
	}

	uvs := make([dynamic]UV, VERTICES_PER_NINE_SLICED_QUAD, allocator)
	for cell, i in core.rect_split_to_grid(uv_rect, relative_offset) {
		rect_uvs := rect_to_uvs(cell)
		copy(uvs[i * VERTICES_PER_QUAD:], rect_uvs[:])
	}
	return uvs
}

// --- UVs to ... ---
uvs_mirror :: proc(uvs: []UV, bounds: core.Rect, flip: core.Flip) {
	c := UV{2 * bounds.x + bounds.w, 2 * bounds.y + bounds.h}
	for &uv in uvs {
		if .X in flip {uv.x = c.x - uv.x}
		if .Y in flip {uv.y = c.y - uv.y}
	}
}

// --- Point to ... ---

point_to_vertex :: proc {
	point_to_vertex_xy,
	point_to_vertex_array,
}

@(private = "file")
point_to_vertex_xy :: proc(x: f32, y: f32) -> Position {
	return {x, y, 0, 1}
}

@(private = "file")
point_to_vertex_array :: proc(point: [2]f32) -> Position {
	return {point.x, point.y, 0, 1}
}

points_to_vertices_positions :: proc(points: [][2]f32) -> [dynamic]Position {
	vertices := make([dynamic]Position, context.temp_allocator)

	for point in points {
		append(&vertices, point_to_vertex(point))
	}

	return vertices
}

points_to_vertices_positions_thickness :: proc(
	points: [][2]f32,
	thickness: int,
) -> [dynamic]Position {
	vertices := make([dynamic]Position, context.temp_allocator)
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

// --- Vertices Positions to ... ---

vertices_positions_to_vertices :: proc(
	positions: []Position,
	color: core.Color,
	mode: Mode = Mode{},
	texture_id: TextureID = TextureID{},
) -> []Vertex2D {
	vertices := make([dynamic]Vertex2D, len(positions), context.temp_allocator)
	for p, i in positions {
		vertices[i] = Vertex2D {
			position   = p,
			color      = core.color_to_linear32(color),
			mode       = mode,
			texture_id = texture_id,
		}
	}

	return vertices[:]
}

vertices_positions_and_uvs_to_vertices :: proc(
	positions: []Position,
	uvs: []UV,
	color: core.Color,
	mode: Mode = Mode{},
	texture_id: TextureID = TextureID{},
) -> []Vertex2D {
	vertices := make([dynamic]Vertex2D, len(positions), context.temp_allocator)
	for p, i in positions {
		vertices[i] = Vertex2D {
			position   = p,
			uv         = uvs[i],
			color      = core.color_to_linear32(color),
			mode       = mode,
			texture_id = texture_id,
		}
	}

	return vertices[:]
}
