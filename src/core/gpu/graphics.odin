package omegpu

import MTL "vendor:darwin/Metal"

import "ome:core"

graphics_append_render_call :: proc(
	renderer: ^Renderer,
	type: MTL.PrimitiveType,
	start, count: int,
) {
	mergable := type == .Point || type == .Line || type == .Triangle
	n := len(renderer.render_calls)
	if n > 0 &&
	   mergable &&
	   renderer.render_calls[n - 1].type == type &&
	   renderer.render_calls[n - 1].state == renderer.active_state {
		renderer.render_calls[n - 1].count += count
	} else {
		append(
			&renderer.render_calls,
			RenderCall{type = type, start = start, count = count, state = renderer.active_state},
		)
	}
}

graphics_add_points :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: core.Color,
	fill: bool = false,
	thickness: int = 1,
) {
	start := len(renderer.vertices.cpu)
	positions: [dynamic]Position

	if thickness > 1 {
		positions = points_to_vertices_positions_thickness(points, thickness)
	} else {
		positions = points_to_vertices_positions(points)
	}

	vertices: []Vertex2D = vertices_positions_to_vertices(positions[:], color)
	gpu_buffer_append(&renderer.vertices, vertices[:])

	type: MTL.PrimitiveType = .LineStrip
	if fill || thickness > 1 do type = .Triangle
	graphics_append_render_call(renderer, type, start, len(vertices))
}

graphics_add_quad :: proc(renderer: ^Renderer, rect: core.Rect, color: core.Color) {
	start := len(renderer.vertices.cpu)
	positions := rect_to_vertices_positions(rect)

	vertices := vertices_positions_to_vertices(positions[:], color)

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
	color: core.Color,
	slice_offset: Maybe(core.RectOffset) = nil,
) {
	start := len(renderer.vertices.cpu)

	vertices := vertices_positions_and_uvs_to_vertices(
		positions[:],
		uvs[:],
		color,
		Mode.Texture,
		TexID(texture_handle.idx),
	)

	gpu_buffer_append(&renderer.vertices, vertices)

	graphics_append_render_call(renderer, .Triangle, start, len(vertices))
}

graphics_add_mesh :: proc(
	renderer: ^Renderer,
	positions: []Position,
	color: core.Color,
	cull: MTL.CullMode = .Back,
) {
	start := len(renderer.vertices.cpu)
	vertices := vertices_positions_to_vertices(positions, color)
	gpu_buffer_append(&renderer.vertices, vertices)

	previous := renderer.active_state
	renderer.active_state.cull = cull
	graphics_append_render_call(renderer, .Triangle, start, len(vertices))
	renderer.active_state = previous
}
