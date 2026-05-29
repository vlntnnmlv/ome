package ome

import "core:log"
import "core:os"
import "core:time"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

Vertex :: distinct [4]f32
Uv :: distinct [2]f32
Mode :: distinct u32
TexID :: distinct u32

App :: struct {
	width:           i32,
	height:          i32,
	pixel_ratio:     f32,
	window:          ^SDL.Window,
	swapchain:       ^CA.MetalLayer,
	command_q:       ^MTL.CommandQueue,
	compile_options: ^MTL.CompileOptions,
	pipeline_state:  ^MTL.RenderPipelineState,
	device:          ^MTL.Device,
	vertices:        GPUBuffer(Vertex),
	colors:          GPUBuffer(Color),
	render_calls:    [dynamic]RenderCall,
	clear_color:     MTL.ClearColor,
	//
	// Runtime
	key_callbacks:   map[u64]KeyCallback,
	quit:            bool,
	fps:             f64,
	frame_count:     int,
	frame_start:     time.Time,
	elapsed:         time.Duration,
	start_time:      time.Time,
	dt:              f32,
	//
	// UI
	ui_context:      UIContext,
	//
	// Textures
	texture_manager: ^TextureManager,
	tex_ids:         GPUBuffer(TexID),
	//
	// Fonts
	uvs:             GPUBuffer(Uv),
	modes:           GPUBuffer(Mode),
	font:            Font,
	//
	// Resets each frame
	frame_context:   FrameContext,
}

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

app_create :: proc(
	title: cstring,
	width: i32,
	height: i32,
	clear_color: [4]f64 = {0.1, 0.1, 0.12, 1.0},
) -> (
	^App,
	bool,
) {
	env := SDL.GetEnvironment()
	SDL.SetEnvironmentVariable(env, "METAL_DEVICE_WRAPPER_TYPE", "1", false)
	if ok := SDL.InitSubSystem({.VIDEO}); !ok {
		log.errorf("SDL Video subsystem couldn't initialize: %v", SDL.GetError())
		return nil, false
	}

	window := SDL.CreateWindow(
		title,
		width,
		height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE, .METAL},
	)
	if window == nil {
		log.errorf("SDL window couldn't initialize: %v", SDL.GetError())
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

	pixel_width, pixel_height: i32
	SDL.GetWindowSizeInPixels(window, &pixel_width, &pixel_height)

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

	app := new(App)
	app.window = window
	app.device = device
	app.width = pixel_width
	app.height = pixel_height
	app.pixel_ratio = f32(pixel_width) / f32(width)
	app.swapchain = swapchain
	app.command_q = command_q
	app.compile_options = compile_options
	app.pipeline_state = pipeline_state

	app.vertices = gpu_buffer_create(Vertex, app.device)
	app.colors = gpu_buffer_create(Color, app.device)
	app.uvs = gpu_buffer_create(Uv, app.device)
	app.modes = gpu_buffer_create(Mode, app.device)
	app.tex_ids = gpu_buffer_create(TexID, app.device)

	app.render_calls = make([dynamic]RenderCall)
	app.clear_color = MTL.ClearColor{clear_color.r, clear_color.g, clear_color.b, clear_color.a}
	app.key_callbacks = make(map[u64]KeyCallback)
	app.quit = false
	app.start_time = time.now()

	app.texture_manager = texture_manager_create()
	texture_manager_init(app, app.texture_manager, fragment_program)

	SDL.ShowWindow(window)

	return app, true
}

app_init_ui :: proc(app: ^App) {
	ui_context_init(&app.ui_context)
	app.ui_context.root_handle = ui_create_panel(
		&app.ui_context,
		nil,
		Rect{0, 0, cast(f32)app.width, cast(f32)app.height},
		{.FILL, 0, .FILL, 0},
		TRANSPARENT_COLOR,
	)
}

KeyCallback :: proc(app: ^App)
app_process_events :: proc(app: ^App) {
	app.frame_start = time.now()

	for e: SDL.Event; SDL.PollEvent(&e); {
		#partial switch e.type {
		case .QUIT:
			app.quit = true
		case .KEY_DOWN:
			if e.key.key == SDL.K_ESCAPE {
				app.quit = true
			}
			callback, ok := app.key_callbacks[cast(u64)e.key.key]
			if ok {
				callback(app)
			}
		}
	}
}

app_pre_render :: proc(app: ^App) {
	app.frame_context.pool = NS.AutoreleasePool.alloc()->init()

	app.frame_context.drawable = app.swapchain->nextDrawable()
	assert(app.frame_context.drawable != nil)

	pass := MTL.RenderPassDescriptor.renderPassDescriptor()
	color_attachment := pass->colorAttachments()->object(0)
	assert(color_attachment != nil)
	color_attachment->setClearColor(app.clear_color)
	color_attachment->setLoadAction(.Clear)
	color_attachment->setStoreAction(.Store)
	color_attachment->setTexture(app.frame_context.drawable->texture())

	app.frame_context.command_buffer = app.command_q->commandBuffer()
	app.frame_context.encoder = app.frame_context.command_buffer->renderCommandEncoderWithDescriptor(
		pass,
	)

	gpu_buffer_clear(&app.vertices)
	gpu_buffer_clear(&app.colors)
	gpu_buffer_clear(&app.uvs)
	gpu_buffer_clear(&app.modes)
	gpu_buffer_clear(&app.tex_ids)
	clear(&app.render_calls)
}

app_render :: proc(app: ^App) {
	app_add_ui_panel(app, &app.ui_context, app.ui_context.root_handle)

	gpu_buffer_submit(&app.vertices)
	gpu_buffer_submit(&app.colors)
	gpu_buffer_submit(&app.uvs)
	gpu_buffer_submit(&app.modes)
	gpu_buffer_submit(&app.tex_ids)

	app.frame_context.encoder->setRenderPipelineState(app.pipeline_state)
	app.frame_context.encoder->setVertexBuffer(app.vertices.gpu, 0, 0)
	app.frame_context.encoder->setVertexBuffer(app.colors.gpu, 0, 1)
	app.frame_context.encoder->setVertexBuffer(app.uvs.gpu, 0, 2)
	app.frame_context.encoder->setVertexBuffer(app.modes.gpu, 0, 3)
	app.frame_context.encoder->setVertexBuffer(app.tex_ids.gpu, 0, 4)

	if app.font.texture != nil {
		app.frame_context.encoder->setFragmentTexture(app.font.texture, 0)
		app.frame_context.encoder->setFragmentSamplerState(app.font.sampler, 0)
	}

	app.frame_context.encoder->setFragmentBuffer(app.texture_manager.arguments, 0, 0)
	if len(app.texture_manager.textures) > 0 {
		app.frame_context.encoder->useResourcesStages(
			transmute([]^MTL.Resource)app.texture_manager.textures[:],
			{.Read},
			{.Fragment},
		)
	}

	for render_call in app.render_calls {
		app.frame_context.encoder->drawPrimitivesWithInstanceCount(
			render_call.type,
			cast(NS.UInteger)render_call.start,
			cast(NS.UInteger)render_call.count,
			1,
		)
	}
}

app_submit :: proc(app: ^App) {
	app.frame_context.encoder->endEncoding()

	app.frame_context.command_buffer->presentDrawable(app.frame_context.drawable)
	app.frame_context.command_buffer->commit()

	app.frame_context.pool->drain()
	app.frame_context.pool = nil

	// fps
	{
		app.frame_count += 1
		app.elapsed = time.since(app.start_time)
		elapsed_duration := time.duration_seconds(app.elapsed)
		if elapsed_duration >= 1.0 {
			app.fps = f64(app.frame_count) / elapsed_duration

			app.frame_count = 0
			app.start_time = time.now()
		}
	}

	// dt
	{
		app.dt = cast(f32)time.duration_seconds(time.since(app.frame_start))
	}
}

app_close :: proc(app: ^App) {
	ui_context_free(&app.ui_context)

	assets_delete_font(&app.font)
	texture_manager_delete(app.texture_manager)
	free(app.texture_manager)

	delete(app.render_calls)
	gpu_buffer_delete(&app.vertices)
	gpu_buffer_delete(&app.uvs)
	gpu_buffer_delete(&app.colors)
	gpu_buffer_delete(&app.modes)
	gpu_buffer_delete(&app.tex_ids)

	app.compile_options->release()
	SDL.DestroyWindow(app.window)
	SDL.Quit()

	free(app)
}
