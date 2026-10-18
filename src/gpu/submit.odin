package omegpu

import vk "vendor:vulkan"

CullMode :: enum {
	None = 0,
	Front,
	Back,
}

PrimitiveType :: enum {
	Line = 0,
	Line_Strip,
	Triangle,
	Triangle_Strip,
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

@(private)
pixel_format_to_channels :: proc(pixel_format: PixelFormat) -> i32 {
	switch pixel_format {
	case .R8_Unorm:
		return 1
	case .RGBA8_Unorm_sRGB:
		return 4
	}

	return 0
}

@(private)
primitive_type_to_vulkan :: proc(
	primitive_type: PrimitiveType,
) -> (
	vk.PrimitiveTopology,
	TopologyClass,
) {
	switch primitive_type {
	case .Line:
		return .LINE_LIST, .Line
	case .Line_Strip:
		return .LINE_STRIP, .Line
	case .Triangle:
		return .TRIANGLE_LIST, .Triangle
	case .Triangle_Strip:
		return .TRIANGLE_STRIP, .Triangle
	}
	return .TRIANGLE_LIST, .Triangle
}

@(private)
cull_mode_to_vulkan :: proc(cull_mode: CullMode) -> vk.CullModeFlags {
	switch cull_mode {
	case .None:
		return {}
	case .Front:
		return {.FRONT}
	case .Back:
		return {.BACK}
	}
	return {}
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
	if !buffer_upload(&device.vertex_ring, slot, vertices) {
		return
	}
	cmd := device.frames[slot].command_buffer

	vertex_info := vk.DescriptorBufferInfo {
		buffer = device.vertex_ring.ring[slot].handle,
		offset = 0,
		range  = vk.DeviceSize(vk.WHOLE_SIZE),
	}
	write := vk.WriteDescriptorSet {
		sType           = .WRITE_DESCRIPTOR_SET,
		dstBinding      = 0,
		descriptorCount = 1,
		descriptorType  = .STORAGE_BUFFER,
		pBufferInfo     = &vertex_info,
	}
	vk.CmdPushDescriptorSetKHR(cmd, .GRAPHICS, device.pipeline_layout, 1, 1, &write)

	last_class: TopologyClass
	last_topology: vk.PrimitiveTopology
	last_cull: CullMode
	last_view: u32

	for call, i in calls {
		first := i == 0
		topology, class := primitive_type_to_vulkan(call.primitive)

		if first || class != last_class {
			vk.CmdBindPipeline(cmd, .GRAPHICS, device.pipelines[class])
			last_class = class
		}
		if first || topology != last_topology {
			vk.CmdSetPrimitiveTopology(cmd, topology)
			last_topology = topology
		}
		if first || call.cull != last_cull {
			vk.CmdSetCullMode(cmd, cull_mode_to_vulkan(call.cull))
			last_cull = call.cull
		}
		if first || call.view != last_view {
			vk.CmdPushConstants(
				cmd,
				device.pipeline_layout,
				{.VERTEX},
				0,
				size_of(matrix[4, 4]f32),
				&view_projections[call.view],
			)
			last_view = call.view
		}

		vk.CmdDraw(cmd, u32(call.count), 1, u32(call.start), 0)
	}
}
