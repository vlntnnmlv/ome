package ome

import "core:log"
import "core:os"
import "core:slice"
import "core:sync"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

MAX_CAMERAS: u32 : 4

FrameContext :: struct {
	pool:           ^NS.AutoreleasePool,
	drawable:       ^CA.MetalDrawable,
	command_buffer: ^MTL.CommandBuffer,
	encoder:        ^MTL.RenderCommandEncoder,
}

RenderCall :: struct {
	type:   MTL.PrimitiveType,
	start:  int,
	count:  int,
	camera: u32,
}

Renderer :: struct {
	device:               ^MTL.Device,
	command_q:            ^MTL.CommandQueue,
	compile_options:      ^MTL.CompileOptions,
	pipeline_state:       ^MTL.RenderPipelineState,
	swapchain:            ^CA.MetalLayer,
	render_calls:         [dynamic]RenderCall,
	clear_color:          MTL.ClearColor,
	cameras:              [MAX_CAMERAS]Camera2D,
	active_camera:        u32,
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
	window: ^SDL.Window,
	window_info: WindowInfo,
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


	// shader_file, shader_file_load_error := os.read_entire_file_from_path(
	// 	"assets/shaders/shader.metal",
	// 	context.temp_allocator,
	// )

	// defer delete(shader_file, context.temp_allocator)
	// if shader_file_load_error != nil {
	// 	log.errorf(
	// 		"Couldn't load shader files. Error: %v",
	// 		os.error_string(shader_file_load_error),
	// 	)
	// 	return nil, false
	// }

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
	renderer.texture_manager = texture_manager_create()
	renderer.logical_size = {window_info.logical_width, window_info.logical_height}
	renderer.vertices = gpu_buffer_create(Vertex2D, renderer.device)

	renderer.cameras[0] = camera_create(renderer.logical_size)

	// log.infof("%v", camera_get_view_projection(renderer.cameras[0]))

	// TODO: This is just a placehodler
	for i in 1 ..< MAX_CAMERAS {
		renderer.cameras[i] = renderer.cameras[0]
	}
	renderer.active_camera = 0

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

renderer_set_camera :: proc(renderer: ^Renderer, index: u32) {
	assert(index < MAX_CAMERAS)
	renderer.active_camera = index
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
	renderer.active_camera = 0
}

renderer_flush :: proc(renderer: ^Renderer) {
	gpu_buffer_submit(&renderer.vertices, renderer.frame_slot_index)

	renderer.frame_context.encoder->setRenderPipelineState(renderer.pipeline_state)
	renderer.frame_context.encoder->setVertexBuffer(
		renderer.vertices.gpu_ring[renderer.frame_slot_index],
		0,
		1,
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

	last_camera: u32 = max(u32)
	for render_call in renderer.render_calls {
		if render_call.camera != last_camera {
			view_projection := camera_get_view_projection(renderer.cameras[render_call.camera])
			renderer.frame_context.encoder->setVertexBytes(
				slice.bytes_from_ptr(&view_projection, size_of(view_projection)),
				2,
			)
		}
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

// --- RENDERING ---

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
	thickness: int = 1,
	fill: bool = false,
) {
	graphics_add_points(renderer, points, resolve_color(color), fill, thickness)
}

render_curve :: proc(
	renderer: ^Renderer,
	curve_points: [][2]f32,
	color: Maybe(Color) = nil,
	thickness: int = 1,
	fill: bool = false,
) {
	assert(len(curve_points) == 3, "Curve rendering supports only 3 points")

	points: [100][2]f32
	for i in 0 ..< 100 {
		phase: f32 = (f32(i) + 1.0) / 100.0
		a_to_b := interpolate(curve_points[0], curve_points[1], phase)
		b_to_c := interpolate(curve_points[1], curve_points[2], phase)
		points[i] = interpolate(a_to_b, b_to_c, phase)
	}
	render_segments(renderer, points[:], resolve_color(color), thickness, fill)
}


render_quad :: proc(
	renderer: ^Renderer,
	rect: Rect,
	color: Maybe(Color) = nil,
	thickness: int = 1,
	fill: bool = false,
) {
	render_segments(
		renderer,
		{
			{rect.x, rect.y},
			{rect.x + rect.w, rect.y},
			{rect.x + rect.w, rect.y + rect.h},
			{rect.x, rect.y + rect.h},
			{rect.x, rect.y},
		},
		color,
		thickness,
		fill,
	)
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

render_texture :: proc {
	render_texture_by_handle,
	render_texture_by_name,
	render_texture_by_atlas_name,
}

render_texture_by_handle :: proc(
	renderer: ^Renderer,
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	positions: [dynamic]Position
	uvs: [dynamic]Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := renderer.texture_manager.textures[handle]
		tw := cast(f32)tex->width()
		th := cast(f32)tex->height()

		positions = rect_to_vertices_nine_slice(rect, rslice_offset)
		uvs = offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = rect_to_vertices_positions(rect)
		uvs = rect_to_uvs({0, 0, 1, 1})
	}

	graphics_add_texture(renderer, handle, positions[:], uvs[:], resolve_color(color))
}

render_texture_by_name :: proc(
	renderer: ^Renderer,
	name: string,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	i, found := slice.linear_search(renderer.texture_manager.texture_names[:], name)
	if !found {
		return
	}

	handle := TextureHandle(i)

	positions: [dynamic]Position
	uvs: [dynamic]Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := renderer.texture_manager.textures[handle]
		tw := cast(f32)tex->width()
		th := cast(f32)tex->height()

		positions = rect_to_vertices_nine_slice(rect, rslice_offset)
		uvs = offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = rect_to_vertices_positions(rect)
		uvs = rect_to_uvs({0, 0, 1, 1})
	}

	graphics_add_texture(renderer, handle, positions[:], uvs[:], resolve_color(color))
}

render_texture_by_atlas_name :: proc(
	renderer: ^Renderer,
	atlas: SpriteAtlas,
	name: string,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	handle := atlas.handle

	positions: [dynamic]Position
	uvs: []Uv

	sprite: SpriteData = atlas.sprites[name]

	if rslice_offset, ok := slice_offset.?; ok {
		// tex := renderer.texture_manager.textures[handle]

		positions = rect_to_vertices_nine_slice(rect, rslice_offset)
		uvs = rect_to_uvs_nine_slice_atlas(
			rslice_offset,
			sprite.atlas_rect,
			{atlas.size, atlas.size},
		)[:]
	} else {
		positions = rect_to_vertices_positions(rect)
		uvs = sprite.uvs
	}

	graphics_add_texture(renderer, handle, positions[:], uvs, resolve_color(color))
}

renderer_resize :: proc(
	renderer: ^Renderer,
	logical_width, logical_height, pixel_width, pixel_height: int,
) {
	renderer.logical_size = {logical_width, logical_height}
	renderer.cameras[0] = camera_create(renderer.logical_size)

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
