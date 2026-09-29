package omegpu

import "core:log"
import "core:sync"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import "ome:platform"

FrameContext :: struct {
	pool:           ^NS.AutoreleasePool,
	drawable:       ^CA.MetalDrawable,
	command_buffer: ^MTL.CommandBuffer,
	encoder:        ^MTL.RenderCommandEncoder,
}

Device :: struct {
	native:               ^MTL.Device,
	command_queue:        ^MTL.CommandQueue,
	pipeline_state:       ^MTL.RenderPipelineState,
	swapchain:            ^CA.MetalLayer,
	clear_color:          MTL.ClearColor,
	bind_table:           ^BindTable,
	vertex_ring:          Buffer(Vertex2D),
	frame_context:        FrameContext,
	frame_slot_index:     int,
	frame_sema:           sync.Sema,
	frame_complete_block: ^NS.Block,
}

device_create :: proc(
	native_window: platform.NativeWindowHandle,
	window_info: platform.WindowInfo,
	clear_color: [4]f64,
) -> (
	^Device,
	bool,
) {
	ns_window := (^NS.Window)(native_window)
	if ns_window == nil {
		log.errorf("gpu/device: couldn't get native window")
		return nil, false
	}

	mtl_device := MTL.CreateSystemDefaultDevice()
	if mtl_device == nil {
		log.errorf("gpu/device: couldn't create default metal device")
		return nil, false
	}

	ok := false
	defer if !ok {
		mtl_device->release()
	}

	if mtl_device->argumentBuffersSupport() != .Tier2 {
		log.errorf("gpu/device: argument buffers aren't supported")
		return nil, false
	}

	shader_source, shader_ok := shader_compile_slang("assets/shaders/shader.slang")
	if !shader_ok {
		return nil, false
	}

	source := NS.String.alloc()->initWithOdinString(string(shader_source))
	defer source->release()
	compile_options := NS.new(MTL.CompileOptions)
	defer compile_options->release()

	program_library, lib_error := mtl_device->newLibraryWithSource(source, compile_options)
	if lib_error != nil {
		log.errorf(
			"gpu/device: shader compilation failed with error %v",
			lib_error->localizedDescription(),
		)
		return nil, false
	}
	defer program_library->release()

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	if vertex_program == nil {
		log.errorf("gpu/device: shader vertex function extraction failed")
		return nil, false
	}
	defer vertex_program->release()

	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))
	if fragment_program == nil {
		log.errorf("gpu/device: shader fragment function extraction failed")
		return nil, false
	}
	defer fragment_program->release()

	pipeline_state_descriptor := NS.new(MTL.RenderPipelineDescriptor)
	defer pipeline_state_descriptor->release()

	pipeline_state_descriptor->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)
	pipeline_state_descriptor->setVertexFunction(vertex_program)
	pipeline_state_descriptor->setFragmentFunction(fragment_program)
	color_attachments := pipeline_state_descriptor->colorAttachments()->object(0)

	color_attachments->setBlendingEnabled(true)
	color_attachments->setRgbBlendOperation(.Add)
	color_attachments->setAlphaBlendOperation(.Add)
	color_attachments->setSourceRGBBlendFactor(.SourceAlpha)
	color_attachments->setSourceAlphaBlendFactor(.SourceAlpha)
	color_attachments->setDestinationRGBBlendFactor(.OneMinusSourceAlpha)
	color_attachments->setDestinationAlphaBlendFactor(.OneMinusSourceAlpha)

	pipeline_state, pipeline_error := mtl_device->newRenderPipelineState(pipeline_state_descriptor)
	if pipeline_error != nil {
		log.errorf(
			"gpu/device: pipeline creation failed with error: %v",
			pipeline_error->localizedDescription(),
		)
		return nil, false
	}

	swapchain := CA.MetalLayer.layer()
	swapchain->setDrawableSize(
		NS.Size{NS.Float(window_info.pixel_width), NS.Float(window_info.pixel_height)},
	)
	swapchain->setDevice(mtl_device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(ns_window->frame())

	ns_window->contentView()->setLayer(swapchain)
	ns_window->setOpaque(true)
	ns_window->setBackgroundColor(nil)

	device := new(Device)
	device.native = mtl_device
	device.swapchain = swapchain
	device.command_queue = mtl_device->newCommandQueue()
	device.pipeline_state = pipeline_state
	device.clear_color = MTL.ClearColor{clear_color.r, clear_color.g, clear_color.b, clear_color.a}
	device.bind_table = bind_table_create(device.native, fragment_program)
	device.vertex_ring = buffer_create(Vertex2D, mtl_device)

	sync.sema_post(&device.frame_sema, GPU_BUFFERS_RING_SIZE)
	device.frame_complete_block, _ = NS.Block.createGlobal(
		&device.frame_sema,
		device_on_frame_complete,
	)

	ok = true
	return device, true
}

device_begin :: proc(device: ^Device) -> bool {
	sync.sema_wait(&device.frame_sema)

	device.frame_context.pool = NS.AutoreleasePool.alloc()->init()

	device.frame_context.drawable = device.swapchain->nextDrawable()
	if device.frame_context.drawable == nil {
		device.frame_context.pool->drain()
		device.frame_context.pool = nil
		sync.sema_post(&device.frame_sema)
		return false
	}

	device.frame_slot_index = (device.frame_slot_index + 1) % GPU_BUFFERS_RING_SIZE
	bind_table_begin_frame(device.bind_table)

	pass := MTL.RenderPassDescriptor.renderPassDescriptor()
	color_attachment := pass->colorAttachments()->object(0)
	assert(color_attachment != nil)
	color_attachment->setClearColor(device.clear_color)
	color_attachment->setLoadAction(.Clear)
	color_attachment->setStoreAction(.Store)
	color_attachment->setTexture(device.frame_context.drawable->texture())

	device.frame_context.command_buffer = device.command_queue->commandBuffer()
	device.frame_context.encoder = device.frame_context.command_buffer->renderCommandEncoderWithDescriptor(
		pass,
	)
	return true
}

device_present :: proc(device: ^Device) {
	device.frame_context.command_buffer->addCompletedHandler(
		MTL.CommandBufferHandler(device.frame_complete_block),
	)

	device.frame_context.encoder->endEncoding()

	device.frame_context.command_buffer->presentDrawable(device.frame_context.drawable)
	device.frame_context.command_buffer->commit()

	device.frame_context.pool->drain()
	device.frame_context.pool = nil
}

device_resize :: proc(device: ^Device, window_info: platform.WindowInfo) {
	device.swapchain->setDrawableSize(
		NS.Size{NS.Float(window_info.pixel_width), NS.Float(window_info.pixel_height)},
	)
}

device_wait_idle :: proc(device: ^Device) {
	for _ in 0 ..< GPU_BUFFERS_RING_SIZE {
		sync.sema_wait(&device.frame_sema)
	}
	sync.sema_post(&device.frame_sema, GPU_BUFFERS_RING_SIZE)
}

@(private = "file")
device_on_frame_complete :: proc "c" (user_data: rawptr) {
	sync.sema_post((^sync.Sema)(user_data))
}

device_destroy :: proc(device: ^Device) {
	buffer_destroy(&device.vertex_ring)
	bind_table_destroy(device.bind_table)
	free(device.frame_complete_block)

	device.pipeline_state->release()
	device.command_queue->release()
	device.native->release()

	free(device)
}
