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
	mtl_device := MTL.CreateSystemDefaultDevice()

	if mtl_device == nil {
		log.errorf("gpu/device: couldn't create default metal device")
		return nil, false
	}

	argument_buffer_support := mtl_device->argumentBuffersSupport()
	if argument_buffer_support != .Tier2 {
		log.errorf("gpu/device: argument buffers aren't supported")
		return nil, false
	}

	native_window := (^NS.Window)(native_window)
	if native_window == nil {
		log.errorf("gpu/device: couldn't get native window")
		return nil, false
	}

	swapchain := CA.MetalLayer.layer()
	swapchain->setDrawableSize(
		NS.Size{NS.Float(window_info.pixel_width), NS.Float(window_info.pixel_height)},
	)
	swapchain->setDevice(mtl_device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	command_queue := mtl_device->newCommandQueue()
	compile_options := NS.new(MTL.CompileOptions)

	shader_source, ok := shader_compile_slang("assets/shaders/shader.slang")
	if !ok {
		return nil, false
	}
	program_library, lib_error := mtl_device->newLibraryWithSource(
		NS.String.alloc()->initWithOdinString(string(shader_source)),
		compile_options,
	)
	if lib_error != nil {
		log.errorf(
			"gpu/device: shader compilation failed with error: %v",
			lib_error->localizedDescription(),
		)
		return nil, false
	}

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))

	if vertex_program == nil {
		log.errorf("gpu/device: shader vertex function extraction failed")
		return nil, false
	}

	if fragment_program == nil {
		log.errorf("gpu/device: shader fragment function extraction failed")
		return nil, false
	}

	pipeline_state_descriptor := NS.new(MTL.RenderPipelineDescriptor)
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

	device := new(Device)

	device.native = mtl_device
	device.swapchain = swapchain
	device.command_queue = command_queue
	device.pipeline_state = pipeline_state

	device.clear_color = MTL.ClearColor{clear_color.r, clear_color.g, clear_color.b, clear_color.a}

	device.bind_table = bind_table_create(device.native, fragment_program)

	sync.sema_post(&device.frame_sema, GPU_BUFFERS_RING_SIZE)
	device.frame_complete_block, _ = NS.Block.createGlobal(
		&device.frame_sema,
		device_on_frame_complete,
	)

	return device, true
}

device_begin :: proc(renderer: ^Device) {
	device_wait_on_frame_complete(renderer)

	renderer.frame_context.pool = NS.AutoreleasePool.alloc()->init()

	renderer.frame_context.drawable = renderer.swapchain->nextDrawable()
	assert(renderer.frame_context.drawable != nil)

	pass := MTL.RenderPassDescriptor.renderPassDescriptor()
	color_attachment := pass->colorAttachments()->object(0)
	assert(color_attachment != nil)
	color_attachment->setClearColor(renderer.clear_color)
	color_attachment->setLoadAction(.Clear)
	color_attachment->setStoreAction(.Store)
	color_attachment->setTexture(renderer.frame_context.drawable->texture())

	renderer.frame_context.command_buffer = renderer.command_queue->commandBuffer()
	renderer.frame_context.encoder = renderer.frame_context.command_buffer->renderCommandEncoderWithDescriptor(
		pass,
	)
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

device_destroy :: proc(device: ^Device) {
	bind_table_destroy(device.bind_table)
	free(device.frame_complete_block)

	device.pipeline_state->release()
	device.command_queue->release()
	device.native->release()

	free(device)
}

device_wait_idle :: proc(device: ^Device) {
	for _ in 0 ..< GPU_BUFFERS_RING_SIZE {
		sync.sema_wait(&device.frame_sema)
	}
	sync.sema_post(&device.frame_sema, GPU_BUFFERS_RING_SIZE)
}

@(private)
device_wait_on_frame_complete :: proc(renderer: ^Device) {
	sync.sema_wait(&renderer.frame_sema)
	renderer.frame_slot_index = (renderer.frame_slot_index + 1) % GPU_BUFFERS_RING_SIZE
}

@(private = "file")
device_on_frame_complete :: proc "c" (user_data: rawptr) {
	sync.sema_post((^sync.Sema)(user_data))
}
