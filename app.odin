package ome

import "core:fmt"
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
	positions:       GPUBuffer(Vertex),
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

app: ^App

app_create :: proc(
	title: cstring,
	width: i32,
	height: i32,
	clear_color: [4]f64 = {0.1, 0.1, 0.12, 1.0},
) -> bool {
	env := SDL.GetEnvironment()
	SDL.SetEnvironmentVariable(env, "METAL_DEVICE_WRAPPER_TYPE", "1", false)
	if ok := SDL.InitSubSystem({.VIDEO}); !ok {
		return ok
	}

	app = new(App)
	app.window = SDL.CreateWindow(
		title,
		width,
		height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE, .METAL},
	)

	native_window := (^NS.Window)(
		SDL.GetPointerProperty(
			SDL.GetWindowProperties(app.window),
			SDL.PROP_WINDOW_COCOA_WINDOW_POINTER,
			nil,
		),
	)
	assert(native_window != nil)

	pixel_width, pixel_height: i32
	SDL.GetWindowSizeInPixels(app.window, &pixel_width, &pixel_height)
	app.width = pixel_width
	app.height = pixel_height
	app.pixel_ratio = f32(pixel_width) / f32(width)

	app.device = MTL.CreateSystemDefaultDevice()

	argument_buffer_support := app.device->argumentBuffersSupport()
	if argument_buffer_support != .Tier2 {
		return false
	}
	fmt.println("Tier 2: OK")

	app.swapchain = CA.MetalLayer.layer()
	app.swapchain->setDrawableSize(NS.Size{cast(NS.Float)pixel_width, cast(NS.Float)pixel_height})
	app.swapchain->setDevice(app.device)
	app.swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	app.swapchain->setFramebufferOnly(true)
	app.swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(app.swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	app.command_q = app.device->newCommandQueue()

	app.compile_options = NS.new(MTL.CompileOptions)

	shader_file, shader_file_load_error := os.read_entire_file_from_path(
		"assets/shader.metal",
		context.allocator,
	)

	defer delete(shader_file, context.allocator)
	if shader_file_load_error != nil {
		return false
	}

	program_library, lib_error := app.device->newLibraryWithSource(
		NS.String.alloc()->initWithOdinString(string(shader_file)),
		app.compile_options,
	)
	if lib_error != nil {
		fmt.eprintln("Shader compile failed:", lib_error->localizedDescription()->odinString())
		return false
	}

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))

	assert(vertex_program != nil)
	assert(fragment_program != nil)

	app.texture_manager = texture_manager_create()
	texture_manager_init(app.texture_manager, fragment_program)

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

	pipeline_error: ^NS.Error
	app.pipeline_state, pipeline_error = app.device->newRenderPipelineState(
		pipeline_state_descriptor,
	)
	if pipeline_error != nil {
		return false
	}

	app.positions = gpu_buffer_create(Vertex, app.device)
	app.colors = gpu_buffer_create(Color, app.device)
	app.uvs = gpu_buffer_create(Uv, app.device)
	app.modes = gpu_buffer_create(Mode, app.device)
	app.tex_ids = gpu_buffer_create(TexID, app.device)

	SDL.ShowWindow(app.window)

	app.clear_color = MTL.ClearColor{clear_color.r, clear_color.g, clear_color.b, clear_color.a}
	app.key_callbacks = make(map[u64]KeyCallback)
	app.quit = false

	return true
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

	gpu_buffer_clear(&app.positions)
	gpu_buffer_clear(&app.colors)
	gpu_buffer_clear(&app.uvs)
	gpu_buffer_clear(&app.modes)
	gpu_buffer_clear(&app.tex_ids)
	clear(&app.render_calls)
}

app_render :: proc(app: ^App) {
	// app_add_ui_panel(app, &app.ui_context, app.ui_context.root_handle)

	gpu_buffer_submit(&app.positions)
	gpu_buffer_submit(&app.colors)
	gpu_buffer_submit(&app.uvs)
	gpu_buffer_submit(&app.modes)
	gpu_buffer_submit(&app.tex_ids)

	app.frame_context.encoder->setRenderPipelineState(app.pipeline_state)
	app.frame_context.encoder->setVertexBuffer(app.positions.gpu, 0, 0)
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
	app.compile_options->release()
	SDL.DestroyWindow(app.window)
	SDL.Quit()
}
