package ome

import "core:log"
import "core:os"
import "core:sync"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

FrameContext :: struct {
	pool:           ^NS.AutoreleasePool,
	drawable:       ^CA.MetalDrawable,
	command_buffer: ^MTL.CommandBuffer,
	encoder:        ^MTL.RenderCommandEncoder,
}

RenderCall :: struct {
	type:  MTL.PrimitiveType,
	start: int,
	count: int,
}

Renderer :: struct {
	device:               ^MTL.Device,
	command_q:            ^MTL.CommandQueue,
	compile_options:      ^MTL.CompileOptions,
	pipeline_state:       ^MTL.RenderPipelineState,
	swapchain:            ^CA.MetalLayer,
	render_calls:         [dynamic]RenderCall,
	clear_color:          MTL.ClearColor,
	texture_manager:      ^TextureManager,
	font:                 Font,
	logical_size:         [2]int,
	vertices:             GPUBuffer(Vertex2D),
	frame_context:        FrameContext,
	//
	// Internal
	frame_slot_index:     int,
	frame_sema:           sync.Sema,
	frame_complete_block: ^NS.Block,
}

renderer_create :: proc(
	window: ^SDL.Window,
	logical_width, logical_height, pixel_width, pixel_height: int,
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

	native_window := (^NS.Window)(
		SDL.GetPointerProperty(
			SDL.GetWindowProperties(window),
			SDL.PROP_WINDOW_COCOA_WINDOW_POINTER,
			nil,
		),
	)
	if native_window == nil {
		log.errorf("Couldn't get native window")
		return nil, false
	}

	swapchain := CA.MetalLayer.layer()
	swapchain->setDrawableSize(NS.Size{cast(NS.Float)pixel_width, cast(NS.Float)pixel_height})
	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	command_q := device->newCommandQueue()
	compile_options := NS.new(MTL.CompileOptions)

	shader_file, shader_file_load_error := os.read_entire_file_from_path(
		"assets/shaders/shader.metal",
		context.temp_allocator,
	)

	defer delete(shader_file, context.temp_allocator)
	if shader_file_load_error != nil {
		log.errorf(
			"Couldn't load shader files. Error: %v",
			os.error_string(shader_file_load_error),
		)
		return nil, false
	}

	program_library, lib_error := device->newLibraryWithSource(
		NS.String.alloc()->initWithOdinString(string(shader_file)),
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
	renderer.texture_manager = texture_manager_create()
	renderer.logical_size = {logical_width, logical_height}
	renderer.vertices = gpu_buffer_create(Vertex2D, renderer.device)

	renderer.clear_color = MTL.ClearColor {
		clear_color.r,
		clear_color.g,
		clear_color.b,
		clear_color.a,
	}

	texture_manager_init(renderer.texture_manager, renderer, fragment_program)

	sync.sema_post(&renderer.frame_sema, GPU_BUFFERS_RING_SIZE)
	renderer.frame_complete_block, _ = NS.Block.createGlobal(
		&renderer.frame_sema,
		renderer_on_frame_complete,
	)

	return renderer, true
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
	// gpu_buffer_clear(&renderer.colors)
	// gpu_buffer_clear(&renderer.uvs)
	// gpu_buffer_clear(&renderer.modes)
	// gpu_buffer_clear(&renderer.tex_ids)

	clear(&renderer.render_calls)
}

renderer_flush :: proc(renderer: ^Renderer) {
	gpu_buffer_submit(&renderer.vertices, renderer.frame_slot_index)

	renderer.frame_context.encoder->setRenderPipelineState(renderer.pipeline_state)
	renderer.frame_context.encoder->setVertexBuffer(
		renderer.vertices.gpu_ring[renderer.frame_slot_index],
		0,
		0,
	)

	if renderer.font.texture != nil {
		renderer.frame_context.encoder->setFragmentTexture(renderer.font.texture, 0)
		renderer.frame_context.encoder->setFragmentSamplerState(renderer.font.sampler, 0)
	}

	renderer.frame_context.encoder->setFragmentBuffer(renderer.texture_manager.arguments, 0, 0)
	if len(renderer.texture_manager.textures) > 0 {
		renderer.frame_context.encoder->useResourcesStages(
			transmute([]^MTL.Resource)renderer.texture_manager.textures[:],
			{.Read},
			{.Fragment},
		)
	}

	for render_call in renderer.render_calls {
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

@(private = "file")
resolve_color :: proc(color: Maybe(Color)) -> Color {
	if real_color, ok := color.?; ok {
		return real_color
	}
	return BLACK_COLOR
}

render_line :: proc(
	renderer: ^Renderer,
	start: [2]f32,
	end: [2]f32,
	color: Maybe(Color) = nil,
	thickness: int = 1,
) {
	graphics_add_points(renderer, {start, end}, resolve_color(color), false, thickness)
}

render_segments :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	graphics_add_points(renderer, points, resolve_color(color), fill)
}

render_rect :: proc(renderer: ^Renderer, rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(renderer, rect, resolve_color(color))
}

render_text :: proc(
	renderer: ^Renderer,
	text: string,
	font_size: u32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	graphics_add_text(renderer, text, font_size, rect, resolve_color(color))
}

render_texture :: proc(
	renderer: ^Renderer,
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	graphics_add_texture(renderer, handle, rect, resolve_color(color), slice_offset)
}

renderer_resize :: proc(
	renderer: ^Renderer,
	logical_width, logical_height, pixel_width, pixel_height: int,
) {
	renderer.logical_size = {logical_width, logical_height}
	renderer.swapchain->setDrawableSize(
		NS.Size{cast(NS.Float)pixel_width, cast(NS.Float)pixel_height},
	)
}

renderer_delete :: proc(renderer: ^Renderer) {
	for _ in 0 ..< GPU_BUFFERS_RING_SIZE {
		sync.sema_wait(&renderer.frame_sema)
	}

	assets_delete_font(&renderer.font)

	texture_manager_delete(renderer.texture_manager)
	free(renderer.texture_manager)

	delete(renderer.render_calls)
	gpu_buffer_delete(&renderer.vertices)

	free(renderer.frame_complete_block)

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
