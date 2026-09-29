package omerender

import "ome:gpu"

import "ome:core"
import "ome:platform"

MAX_CAMERAS: u32 : 4
INITIAL_VERTEX_CAPACITY :: 1024

Batch :: struct {
	vertices:     [dynamic]gpu.Vertex2D,
	calls:        [dynamic]gpu.RenderCall,
	active_state: gpu.RenderState,
	cameras:      [MAX_CAMERAS]core.Camera,
}

@(private)
batch_create :: proc(window_info: platform.WindowInfo) -> Batch {
	batch := Batch {
		vertices = make([dynamic]gpu.Vertex2D),
		calls    = make([dynamic]gpu.RenderCall),
	}

	logical_size: [2]f32 = {window_info.logical_width, window_info.logical_height}

	for &camera in batch.cameras {
		camera = core.camera2d_create(logical_size)
	}

	return batch
}

@(private)
batch_clear :: proc(batch: ^Batch) {
	clear(&batch.vertices)
	clear(&batch.calls)
	batch.active_state = gpu.RenderState{}
}

@(private)
batch_destroy :: proc(batch: ^Batch) {
	delete(batch.vertices)
	delete(batch.calls)
}

@(private)
batch_resize :: proc(batch: ^Batch, window_info: platform.WindowInfo) {
	logical_size: [2]f32 = {window_info.logical_width, window_info.logical_height}
	for &camera in batch.cameras {
		core.camera_set_viewport_size(&camera, logical_size)
	}
}

@(private)
batch_reserve :: proc(batch: ^Batch, primitive: gpu.PrimitiveType, n: int) -> []gpu.Vertex2D {
	start := len(batch.vertices)
	err := non_zero_resize(&batch.vertices, start + n)
	ensure(err == nil)
	batch_append_render_call(batch, primitive, start, n)
	return batch.vertices[start:]
}

@(private)
batch_append_render_call :: proc(batch: ^Batch, primitive: gpu.PrimitiveType, start, count: int) {
	mergeable := primitive == .Point || primitive == .Line || primitive == .Triangle
	n := len(batch.calls)
	if n > 0 &&
	   mergeable &&
	   batch.calls[n - 1].primitive == primitive &&
	   batch.calls[n - 1].state == batch.active_state {
		batch.calls[n - 1].count += count
		return
	}

	append(
		&batch.calls,
		gpu.RenderCall {
			state = batch.active_state,
			primitive = primitive,
			start = start,
			count = count,
		},
	)
}

@(private)
batch_add_points :: proc(batch: ^Batch, points: [][2]f32, color: core.Color, thickness: int = 1) {
	positions: [dynamic]gpu.Position
	type: gpu.PrimitiveType = .Line_Strip

	if thickness > 1 {
		positions = points_to_vertices_positions_thickness(points, thickness)
		type = .Triangle
	} else {
		positions = points_to_vertices_positions(points)
	}


	destination := batch_reserve(batch, type, len(positions))
	vertices_write(destination, positions[:], nil, color)
}

@(private)
batch_add_quad :: proc(batch: ^Batch, rect: core.Rect, color: core.Color) {
	positions := rect_to_vertices_positions(rect)
	destination := batch_reserve(batch, .Triangle, len(positions))
	vertices_write(destination, positions[:], nil, color)
}

@(private)
batch_add_texture :: proc(
	batch: ^Batch,
	texture_handle: gpu.TextureHandle,
	positions: []gpu.Position,
	uvs: []gpu.UV,
	color: core.Color,
	mode: gpu.Mode = .Texture,
) {
	destination := batch_reserve(batch, .Triangle, len(positions))
	vertices_write(destination, positions, uvs, color, mode, gpu.TextureID(texture_handle.idx))
}

@(private)
batch_add_mesh :: proc(
	batch: ^Batch,
	positions: []gpu.Position,
	color: core.Color,
	cull: gpu.CullMode = .Back,
) {
	previous := batch.active_state
	batch.active_state.cull = cull
	destination := batch_reserve(batch, .Triangle, len(positions))
	batch.active_state = previous
	vertices_write(destination, positions[:], nil, color)
}
