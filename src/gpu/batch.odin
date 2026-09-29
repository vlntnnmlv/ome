package omegpu

import "core:slice"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

import "ome:core"
import "ome:platform"

MAX_CAMERAS: u32 : 4

PrimitiveType :: enum {
	Point = 0,
	Line,
	Line_Strip,
	Triangle,
	Triangle_Strip,
}

@(private)
primitive_type_to_metal :: proc(primitive_type: PrimitiveType) -> MTL.PrimitiveType {
	switch primitive_type {
	case .Point:
		return .Point
	case .Line:
		return .Line
	case .Line_Strip:
		return .LineStrip
	case .Triangle:
		return .Triangle
	case .Triangle_Strip:
		return .TriangleStrip
	}

	return .Point
}

CullMode :: enum {
	None = 0,
	Front,
	Back,
}

@(private)
cull_mode_to_metal :: proc(cull_mode: CullMode) -> MTL.CullMode {
	switch cull_mode {
	case .None:
		return .None
	case .Front:
		return .Front
	case .Back:
		return .Back
	}

	return .None
}

RenderState :: struct {
	camera: u32,
	cull:   CullMode,
}

RenderCall :: struct {
	type:  PrimitiveType,
	start: int,
	count: int,
	state: RenderState,
}

Batch :: struct {
	vertices:     Buffer(Vertex2D),
	render_calls: [dynamic]RenderCall,
	active_state: RenderState,
	cameras:      [MAX_CAMERAS]core.Camera,
	logical_size: [2]f32,
}

batch_clear :: proc(batch: ^Batch) {
	buffer_clear(&batch.vertices)
	clear(&batch.render_calls)
	batch.active_state = RenderState {
		camera = 0,
		cull   = .None,
	}
}

batch_flush :: proc(batch: ^Batch, device: ^Device) {
	buffer_submit(&batch.vertices, device.frame_slot_index)

	device.frame_context.encoder->setRenderPipelineState(device.pipeline_state)
	device.frame_context.encoder->setFrontFacingWinding(.CounterClockwise)
	device.frame_context.encoder->setVertexBuffer(
		batch.vertices.gpu_ring[device.frame_slot_index],
		0,
		1,
	)

	device.frame_context.encoder->setFragmentBuffer(device.bind_table.arguments, 0, 0)
	if len(device.bind_table.resources) > 0 {
		device.frame_context.encoder->useResourcesStages(
			device.bind_table.resources[:],
			{.Read},
			{.Fragment},
		)
	}

	last_state: RenderState = {
		camera = max(u32),
		cull   = .None,
	}
	for render_call in batch.render_calls {
		if render_call.state.camera != last_state.camera {
			view_projection := core.camera_get_view_projection(
				batch.cameras[render_call.state.camera],
			)
			device.frame_context.encoder->setVertexBytes(
				slice.bytes_from_ptr(&view_projection, size_of(view_projection)),
				2,
			)
		}
		if render_call.state.cull != last_state.cull {
			device.frame_context.encoder->setCullMode(cull_mode_to_metal(render_call.state.cull))
		}

		last_state = render_call.state
		device.frame_context.encoder->drawPrimitivesWithInstanceCount(
			primitive_type_to_metal(render_call.type),
			NS.UInteger(render_call.start),
			NS.UInteger(render_call.count),
			1,
		)
	}
}

batch_create :: proc(device: ^Device, window_info: platform.WindowInfo) -> Batch {
	batch: Batch
	batch.render_calls = make([dynamic]RenderCall)
	batch.logical_size = {window_info.logical_width, window_info.logical_height}
	batch.vertices = buffer_create(Vertex2D, device.native)

	batch.cameras[0] = core.camera2d_create(batch.logical_size)
	for i in 1 ..< MAX_CAMERAS {
		batch.cameras[i] = batch.cameras[0]
	}

	batch.active_state = RenderState {
		camera = 0,
		cull   = .None,
	}

	return batch
}

batch_resize :: proc(batch: ^Batch, window_info: platform.WindowInfo) {
	batch.logical_size = {window_info.logical_width, window_info.logical_height}
	for i in 0 ..< MAX_CAMERAS {
		core.camera_set_viewport_size(&batch.cameras[i], batch.logical_size)
	}
}

batch_destroy :: proc(batch: ^Batch) {
	delete(batch.render_calls)
	buffer_destroy(&batch.vertices)
}

batch_set_camera :: proc(batch: ^Batch, index: u32) {
	assert(index < MAX_CAMERAS)
	batch.active_state.camera = index
}

batch_get_camera2d :: proc(batch: ^Batch, index: u32) -> ^core.Camera2D {
	return &batch.cameras[index].(core.Camera2D)
}

batch_get_camera3d :: proc(batch: ^Batch, index: u32) -> ^core.Camera3D {
	return &batch.cameras[index].(core.Camera3D)
}

batch_append_render_call :: proc(batch: ^Batch, type: PrimitiveType, start, count: int) {
	mergeable := type == .Point || type == .Line || type == .Triangle
	n := len(batch.render_calls)
	if n > 0 &&
	   mergeable &&
	   batch.render_calls[n - 1].type == type &&
	   batch.render_calls[n - 1].state == batch.active_state {
		batch.render_calls[n - 1].count += count
	} else {
		append(
			&batch.render_calls,
			RenderCall{type = type, start = start, count = count, state = batch.active_state},
		)
	}
}

batch_add_points :: proc(
	batch: ^Batch,
	points: [][2]f32,
	color: core.Color,
	fill: bool = false,
	thickness: int = 1,
) {
	start := len(batch.vertices.cpu)
	positions: [dynamic]Position

	if thickness > 1 {
		positions = points_to_vertices_positions_thickness(points, thickness)
	} else {
		positions = points_to_vertices_positions(points)
	}

	vertices: []Vertex2D = vertices_positions_to_vertices(positions[:], color)
	buffer_append(&batch.vertices, vertices[:])

	type: PrimitiveType = .Line_Strip
	if fill || thickness > 1 {
		type = .Triangle
	}
	batch_append_render_call(batch, type, start, len(vertices))
}

batch_add_quad :: proc(batch: ^Batch, rect: core.Rect, color: core.Color) {
	start := len(batch.vertices.cpu)
	positions := rect_to_vertices_positions(rect)

	vertices := vertices_positions_to_vertices(positions[:], color)

	buffer_append(&batch.vertices, vertices)

	batch_append_render_call(batch, .Triangle, start, len(vertices))
}

batch_add_texture :: proc(
	batch: ^Batch,
	texture_handle: TextureHandle,
	positions: []Position,
	uvs: []UV,
	color: core.Color,
	slice_offset: Maybe(core.RectOffset) = nil,
) {
	start := len(batch.vertices.cpu)

	vertices := vertices_positions_and_uvs_to_vertices(
		positions[:],
		uvs[:],
		color,
		Mode.Texture,
		TextureID(texture_handle.idx),
	)

	buffer_append(&batch.vertices, vertices)

	batch_append_render_call(batch, .Triangle, start, len(vertices))
}

batch_add_mesh :: proc(
	batch: ^Batch,
	positions: []Position,
	color: core.Color,
	cull: CullMode = .Back,
) {
	start := len(batch.vertices.cpu)
	vertices := vertices_positions_to_vertices(positions, color)
	buffer_append(&batch.vertices, vertices)

	previous := batch.active_state
	batch.active_state.cull = cull
	batch_append_render_call(batch, .Triangle, start, len(vertices))
	batch.active_state = previous
}
