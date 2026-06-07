package ome

import "core:log"

// import NS "core:sys/darwin/Foundation"
// import MTL "vendor:darwin/Metal"
// import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

App :: struct {
	logical_height: int,
	logical_width:  int,
	pixel_width:    int,
	pixel_height:   int,
	pixel_ratio:    f32,
	window:         ^SDL.Window,
	renderer:       ^Renderer,
	key_callbacks:  map[u64]KeyCallback,
	quit:           bool,
	time_manager:   TimeManager,
	ui_context:     UIContext,
}

KeyCallback :: proc(ctx: ^App)

app_create :: proc(
	title: cstring,
	logical_width, logical_height: i32,
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
		logical_width,
		logical_height,
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
	app.logical_width = cast(int)logical_width
	app.logical_height = cast(int)logical_height
	app.pixel_width = cast(int)pixel_width
	app.pixel_height = cast(int)pixel_height
	app.pixel_ratio = f32(app.pixel_width) / f32(app.logical_width)

	if renderer, ok := renderer_create(
		app.window,
		app.logical_width,
		app.logical_height,
		app.pixel_width,
		app.pixel_height,
		clear_color,
	); !ok {
		return nil, false
	} else {
		app.renderer = renderer
	}

	app.key_callbacks = make(map[u64]KeyCallback)
	app.quit = false
	time_manager_start(&app.time_manager)

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
	time_manager_capture_frame_start(&app.time_manager)

	for e: SDL.Event; SDL.PollEvent(&e); {
		#partial switch e.type {
		case .QUIT:
			app.quit = true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			lw, lh, pw, ph: i32
			SDL.GetWindowSizeInPixels(app.window, &pw, &ph)
			SDL.GetWindowSize(app.window, &lw, &lh)

			app.pixel_width = cast(int)pw
			app.pixel_height = cast(int)ph
			app.logical_width = cast(int)lw
			app.logical_height = cast(int)lh

			app.pixel_ratio = f32(app.pixel_width) / f32(app.logical_width)
			renderer_resize(
				app.renderer,
				app.logical_width,
				app.logical_height,
				app.pixel_width,
				app.pixel_height,
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
	renderer_begin(app.renderer)
}

app_render :: proc(app: ^App) {
	renderer_flush(app.renderer)
}

app_submit :: proc(app: ^App) {
	renderer_present(app.renderer)
	time_manager_update(&app.time_manager)
}

app_close :: proc(app: ^App) {
	ui_context_free(&app.ui_context)

	renderer_delete(app.renderer)
	free(app.renderer)

	SDL.DestroyWindow(app.window)
	SDL.Quit()

	free(app)
}
