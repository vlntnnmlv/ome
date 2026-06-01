package ome

import "core:log"
import "core:time"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

App :: struct {
	logical_height:  i32,
	logical_width:   i32,
	pixel_width:     i32,
	pixel_height:    i32,
	pixel_ratio:     f32,
	window:          ^SDL.Window,
	compile_options: ^MTL.CompileOptions,
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
	// Rendering
	renderer:        ^Renderer,
	//
	// UI
	ui_context:      UIContext,
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

KeyCallback :: proc(ctx: ^App)

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

	pixel_width, pixel_height: i32
	SDL.GetWindowSizeInPixels(window, &pixel_width, &pixel_height)

	app := new(App)
	app.window = window
	app.logical_width = width
	app.logical_height = height
	app.pixel_width = pixel_width
	app.pixel_height = pixel_height
	app.pixel_ratio = f32(app.pixel_width) / f32(app.logical_width)

	if renderer, ok := renderer_create(
		app.window,
		app.logical_width,
		app.logical_height,
		app.pixel_width,
		app.pixel_height,
	); !ok {
		return nil, false
	} else {
		app.renderer = renderer
	}

	app.clear_color = MTL.ClearColor{clear_color.r, clear_color.g, clear_color.b, clear_color.a}
	app.key_callbacks = make(map[u64]KeyCallback)
	app.quit = false
	app.start_time = time.now()

	SDL.ShowWindow(window)

	return app, true
}

app_init_ui :: proc(app: ^App) {
	ui_context_init(&app.ui_context)
	app.ui_context.root_handle = ui_create_panel(
		&app.ui_context,
		nil,
		Rect{0, 0, cast(f32)app.pixel_width, cast(f32)app.pixel_height},
		{.FILL, 0, .FILL, 0},
		TRANSPARENT_COLOR,
	)
}

app_process_events :: proc(app: ^App) {
	app.frame_start = time.now()

	for e: SDL.Event; SDL.PollEvent(&e); {
		#partial switch e.type {
		case .QUIT:
			app.quit = true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			SDL.GetWindowSizeInPixels(app.window, &app.pixel_width, &app.pixel_height)
			SDL.GetWindowSize(app.window, &app.logical_width, &app.logical_height)
			app.renderer.logical_size = {app.logical_width, app.logical_height}
			app.pixel_ratio = f32(app.pixel_width) / f32(app.logical_width)
			app.renderer.swapchain->setDrawableSize(
				NS.Size{cast(NS.Float)app.pixel_width, cast(NS.Float)app.pixel_height},
			)
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

	app.frame_context.drawable = app.renderer.swapchain->nextDrawable()
	assert(app.frame_context.drawable != nil)

	pass := MTL.RenderPassDescriptor.renderPassDescriptor()
	color_attachment := pass->colorAttachments()->object(0)
	assert(color_attachment != nil)
	color_attachment->setClearColor(app.clear_color)
	color_attachment->setLoadAction(.Clear)
	color_attachment->setStoreAction(.Store)
	color_attachment->setTexture(app.frame_context.drawable->texture())

	app.frame_context.command_buffer = app.renderer.command_q->commandBuffer()
	app.frame_context.encoder = app.frame_context.command_buffer->renderCommandEncoderWithDescriptor(
		pass,
	)

	gpu_buffer_clear(&app.renderer.vertices)
	gpu_buffer_clear(&app.renderer.colors)
	gpu_buffer_clear(&app.renderer.uvs)
	gpu_buffer_clear(&app.renderer.modes)
	gpu_buffer_clear(&app.renderer.tex_ids)
	clear(&app.renderer.render_calls)
}

app_render :: proc(app: ^App) {
	app_add_ui_panel(app, &app.ui_context, app.ui_context.root_handle)

	gpu_buffer_submit(&app.renderer.vertices)
	gpu_buffer_submit(&app.renderer.colors)
	gpu_buffer_submit(&app.renderer.uvs)
	gpu_buffer_submit(&app.renderer.modes)
	gpu_buffer_submit(&app.renderer.tex_ids)

	app.frame_context.encoder->setRenderPipelineState(app.renderer.pipeline_state)
	app.frame_context.encoder->setVertexBuffer(app.renderer.vertices.gpu, 0, 0)
	app.frame_context.encoder->setVertexBuffer(app.renderer.colors.gpu, 0, 1)
	app.frame_context.encoder->setVertexBuffer(app.renderer.uvs.gpu, 0, 2)
	app.frame_context.encoder->setVertexBuffer(app.renderer.modes.gpu, 0, 3)
	app.frame_context.encoder->setVertexBuffer(app.renderer.tex_ids.gpu, 0, 4)

	if app.renderer.font.texture != nil {
		app.frame_context.encoder->setFragmentTexture(app.renderer.font.texture, 0)
		app.frame_context.encoder->setFragmentSamplerState(app.renderer.font.sampler, 0)
	}

	app.frame_context.encoder->setFragmentBuffer(app.renderer.texture_manager.arguments, 0, 0)
	if len(app.renderer.texture_manager.textures) > 0 {
		app.frame_context.encoder->useResourcesStages(
			transmute([]^MTL.Resource)app.renderer.texture_manager.textures[:],
			{.Read},
			{.Fragment},
		)
	}

	for render_call in app.renderer.render_calls {
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

	assets_delete_font(&app.renderer.font)
	texture_manager_delete(app.renderer.texture_manager)
	free(app.renderer.texture_manager)

	delete(app.renderer.render_calls)
	gpu_buffer_delete(&app.renderer.vertices)
	gpu_buffer_delete(&app.renderer.uvs)
	gpu_buffer_delete(&app.renderer.colors)
	gpu_buffer_delete(&app.renderer.modes)
	gpu_buffer_delete(&app.renderer.tex_ids)
	app.renderer.device->release()

	app.compile_options->release()
	SDL.DestroyWindow(app.window)
	SDL.Quit()

	free(app)
}
