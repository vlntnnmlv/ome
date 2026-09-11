package omegpu

import "core:log"
import "core:os"
import "core:slice"
import "core:sync"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import "ome:core"
import "ome:core/platform"

MAX_CAMERAS: u32 : 4

FrameContext :: struct {
	pool:           ^NS.AutoreleasePool,
	drawable:       ^CA.MetalDrawable,
	command_buffer: ^MTL.CommandBuffer,
	encoder:        ^MTL.RenderCommandEncoder,
}

RenderState :: struct {
	camera: u32,
	cull:   MTL.CullMode,
}

RenderCall :: struct {
	type:  MTL.PrimitiveType,
	start: int,
	count: int,
	state: RenderState,
}

Renderer :: struct {
	device:               ^MTL.Device,
	command_q:            ^MTL.CommandQueue,
	pipeline_state:       ^MTL.RenderPipelineState,
	swapchain:            ^CA.MetalLayer,
	render_calls:         [dynamic]RenderCall,
	clear_color:          MTL.ClearColor,
	cameras:              [MAX_CAMERAS]core.Camera,
	active_state:         RenderState,
	bind_table:           ^BindTable,
	logical_size:         [2]int,
	vertices:             GPUBuffer(Vertex2D),
	frame_context:        FrameContext,
	// Internal
	frame_slot_index:     int,
	frame_sema:           sync.Sema,
	frame_complete_block: ^NS.Block,
}

@(private = "file")
shader_compile_slang :: proc(
	path: string,
	allocator := context.temp_allocator,
) -> (
	source: string,
	ok: bool,
) {
	state, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = {"slangc", path, "-target", "metal"}},
		allocator,
	)
	if err != nil {
		log.errorf("Couldn't run slangc: %v", os.error_string(err))
		return "", false
	}
	if !state.success || state.exit_code != 0 {
		log.errorf("slangc failed (exit %d):\n%s", state.exit_code, string(stderr))
		return "", false
	}
	if len(stderr) > 0 {
		log.warnf("slangc: %s", string(stderr))
	}
	return string(stdout), true
}

renderer_create :: proc(
	native_window: platform.NativeWindowHandle,
	window_info: platform.WindowInfo,
	clear_color: [4]f64,
) -> (
	^Renderer,
	bool,
) {
	device := MTL.CreateSystemDefaultDevice()

	if device == nil {
		log.errorf("Couldn't create default Metal device")
		return nil, false
	}

	argument_buffer_support := device->argumentBuffersSupport()
	if argument_buffer_support != .Tier2 {
		log.errorf("Argument buffers aren't supported")
		return nil, false
	}

	native_window := (^NS.Window)(native_window)
	if native_window == nil {
		log.errorf("Couldn't get native window")
		return nil, false
	}

	swapchain := CA.MetalLayer.layer()
	swapchain->setDrawableSize(
		NS.Size{cast(NS.Float)window_info.pixel_width, cast(NS.Float)window_info.pixel_height},
	)
	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	command_q := device->newCommandQueue()
	compile_options := NS.new(MTL.CompileOptions)

	shader_source, ok := shader_compile_slang("assets/shaders/shader.slang")
	if !ok {
		return nil, false
	}
	program_library, lib_error := device->newLibraryWithSource(
		NS.String.alloc()->initWithOdinString(string(shader_source)),
		compile_options,
	)
	if lib_error != nil {
		log.errorf("Shader compilation failed. Error: %v", lib_error->localizedDescription())
		return nil, false
	}

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))

	if vertex_program == nil {
		log.errorf("Shader vertex function extraction failed.")
		return nil, false
	}

	if fragment_program == nil {
		log.errorf("Shader fragment function extraction failed.")
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

	pipeline_state, pipeline_error := device->newRenderPipelineState(pipeline_state_descriptor)
	if pipeline_error != nil {
		log.errorf("Pipeline creation failed. Error: %v", pipeline_error->localizedDescription())
		return nil, false
	}

	renderer := new(Renderer)

	renderer.device = device
	renderer.swapchain = swapchain
	renderer.command_q = command_q
	renderer.pipeline_state = pipeline_state
	renderer.render_calls = make([dynamic]RenderCall)
	renderer.logical_size = {window_info.logical_width, window_info.logical_height}
	renderer.vertices = gpu_buffer_create(Vertex2D, renderer.device)

	renderer.cameras[0] = core.camera2d_create(renderer.logical_size)

	for i in 1 ..< MAX_CAMERAS {
		renderer.cameras[i] = renderer.cameras[0]
	}

	renderer.active_state = RenderState {
		camera = 0,
		cull   = .None,
	}

	renderer.clear_color = MTL.ClearColor {
		clear_color.r,
		clear_color.g,
		clear_color.b,
		clear_color.a,
	}

	renderer.bind_table = bind_table_create(renderer.device, fragment_program)

	sync.sema_post(&renderer.frame_sema, GPU_BUFFERS_RING_SIZE)
	renderer.frame_complete_block, _ = NS.Block.createGlobal(
		&renderer.frame_sema,
		renderer_on_frame_complete,
	)

	return renderer, true
}

renderer_set_camera :: proc(renderer: ^Renderer, index: u32) {
	assert(index < MAX_CAMERAS)
	renderer.active_state.camera = index
}

renderer_get_camera_2d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera2D {
	return &renderer.cameras[index].(core.Camera2D)
}

renderer_get_camera_3d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera3D {
	return &renderer.cameras[index].(core.Camera3D)
}

renderer_begin :: proc(renderer: ^Renderer) {
	renderer_wait_on_frame_complete(renderer)

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

	renderer.frame_context.command_buffer = renderer.command_q->commandBuffer()
	renderer.frame_context.encoder = renderer.frame_context.command_buffer->renderCommandEncoderWithDescriptor(
		pass,
	)

	gpu_buffer_clear(&renderer.vertices)

	clear(&renderer.render_calls)
	renderer.active_state = {
		camera = 0,
		cull   = .None,
	}
}

renderer_flush :: proc(renderer: ^Renderer) {
	gpu_buffer_submit(&renderer.vertices, renderer.frame_slot_index)

	renderer.frame_context.encoder->setRenderPipelineState(renderer.pipeline_state)
	renderer.frame_context.encoder->setFrontFacingWinding(.CounterClockwise)
	renderer.frame_context.encoder->setVertexBuffer(
		renderer.vertices.gpu_ring[renderer.frame_slot_index],
		0,
		1,
	)

	renderer.frame_context.encoder->setFragmentBuffer(renderer.bind_table.arguments, 0, 0)
	if len(renderer.bind_table.resources) > 0 {
		renderer.frame_context.encoder->useResourcesStages(
			renderer.bind_table.resources[:],
			{.Read},
			{.Fragment},
		)
	}

	last_state: RenderState = {
		camera = max(u32),
		cull   = .None,
	}
	for render_call in renderer.render_calls {
		if render_call.state.camera != last_state.camera {
			view_projection := core.camera_get_view_projection(
				renderer.cameras[render_call.state.camera],
			)
			renderer.frame_context.encoder->setVertexBytes(
				slice.bytes_from_ptr(&view_projection, size_of(view_projection)),
				2,
			)
		}
		if render_call.state.cull != last_state.cull {
			renderer.frame_context.encoder->setCullMode(render_call.state.cull)
		}

		last_state = render_call.state
		renderer.frame_context.encoder->drawPrimitivesWithInstanceCount(
			render_call.type,
			cast(NS.UInteger)render_call.start,
			cast(NS.UInteger)render_call.count,
			1,
		)
	}
}

renderer_present :: proc(renderer: ^Renderer) {
	renderer.frame_context.command_buffer->addCompletedHandler(
		MTL.CommandBufferHandler(renderer.frame_complete_block),
	)

	renderer.frame_context.encoder->endEncoding()

	renderer.frame_context.command_buffer->presentDrawable(renderer.frame_context.drawable)
	renderer.frame_context.command_buffer->commit()

	renderer.frame_context.pool->drain()
	renderer.frame_context.pool = nil
}

renderer_resize :: proc(renderer: ^Renderer, window_info: platform.WindowInfo) {
	renderer.logical_size = {window_info.logical_width, window_info.logical_height}
	for i in 0 ..< MAX_CAMERAS {
		switch _ in renderer.cameras[i] {
		case core.Camera2D:
			renderer.cameras[i] = core.camera2d_create(renderer.logical_size)
		case core.Camera3D:
			c := &renderer.cameras[i].(core.Camera3D)
			c.viewport.w = f32(window_info.logical_width)
			c.viewport.h = f32(window_info.logical_height)
		}
	}

	renderer.swapchain->setDrawableSize(
		NS.Size{cast(NS.Float)window_info.pixel_width, cast(NS.Float)window_info.pixel_height},
	)
}

renderer_delete :: proc(renderer: ^Renderer) {
	for _ in 0 ..< GPU_BUFFERS_RING_SIZE {
		sync.sema_wait(&renderer.frame_sema)
	}

	// font_delete(&renderer.font)

	bind_table_delete(renderer.bind_table)
	free(renderer.bind_table)

	delete(renderer.render_calls)
	gpu_buffer_delete(&renderer.vertices)

	free(renderer.frame_complete_block)

	renderer.pipeline_state->release()
	renderer.command_q->release()
	// renderer.swapchain->release()
	renderer.device->release()

}

@(private)
renderer_wait_on_frame_complete :: proc(renderer: ^Renderer) {
	sync.sema_wait(&renderer.frame_sema)
	renderer.frame_slot_index = (renderer.frame_slot_index + 1) % GPU_BUFFERS_RING_SIZE
}

@(private = "file")
renderer_on_frame_complete :: proc "c" (user_data: rawptr) {
	sync.sema_post((^sync.Sema)(user_data))
}
