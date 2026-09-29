package omegpu

import "core:slice"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

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
	view: u32,
	cull: CullMode,
}

RenderCall :: struct {
	using state: RenderState,
	primitive:   PrimitiveType,
	start:       int,
	count:       int,
}

frame_submit :: proc(
	device: ^Device,
	vertices: []Vertex2D,
	calls: []RenderCall,
	view_projections: []matrix[4, 4]f32,
) {
	if len(calls) == 0 {
		return
	}

	slot := device.frame_slot_index
	buffer_upload(&device.vertex_ring, slot, vertices)

	encoder := device.frame_context.encoder
	encoder->setRenderPipelineState(device.pipeline_state)
	encoder->setFrontFacingWinding(.CounterClockwise)
	encoder->setVertexBuffer(device.vertex_ring.gpu_ring[device.frame_slot_index], 0, 1)

	encoder->setFragmentBuffer(device.bind_table.arguments, 0, 0)
	if len(device.bind_table.resources) > 0 {
		encoder->useResourcesStages(device.bind_table.resources[:], {.Read}, {.Fragment})
	}

	last: RenderState = {
		view = max(u32),
		cull = .None,
	}
	for call in calls {
		if call.view != last.view {
			encoder->setVertexBytes(
				slice.bytes_from_ptr(&view_projections[call.view], size_of(matrix[4, 4]f32)),
				2,
			)
		}

		if call.cull != last.cull {
			encoder->setCullMode(cull_mode_to_metal(call.cull))
		}

		last = call.state
		encoder->drawPrimitivesWithInstanceCount(
			primitive_type_to_metal(call.primitive),
			NS.UInteger(call.start),
			NS.UInteger(call.count),
			1,
		)
	}
}
