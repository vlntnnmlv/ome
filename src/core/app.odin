package omecore

import "core:fmt"
import "core:log"

import SDL "vendor:sdl3"

WindowInfo :: struct {
	logical_height: int,
	logical_width:  int,
	pixel_width:    int,
	pixel_height:   int,
	pixel_ratio:    f32,
}

App :: struct {
	window_info:   WindowInfo,
	window:        ^SDL.Window,
	renderer:      ^Renderer,
	key_callbacks: map[u64]KeyCallback,
	quit:          bool,
	time_manager:  TimeManager,
}

KeyCallback :: proc(ctx: ^App)
app_create :: proc(
	title: cstring,
	logical_width, logical_height: i32,
	clear_color: Color = {0, 34, 44, 255},
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


	// TODO: Add Vulkan support
	window := SDL.CreateWindow(
		title,
		logical_width,
		logical_height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE},
	)

	if window == nil {
		log.errorf("SDL window couldn't initialize: %v", SDL.GetError())
		return nil, false
	}

	pixel_width, pixel_height: i32
	SDL.GetWindowSizeInPixels(window, &pixel_width, &pixel_height)

	app := new(App)
	app.window = window
	app.window_info.logical_width = cast(int)logical_width
	app.window_info.logical_height = cast(int)logical_height
	app.window_info.pixel_width = cast(int)pixel_width
	app.window_info.pixel_height = cast(int)pixel_height
	app.window_info.pixel_ratio =
		f32(app.window_info.pixel_width) / f32(app.window_info.logical_width)

	if renderer, ok := renderer_create(
		app.window,
		app.window_info,
		color_to_linear64(clear_color),
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

app_process_events :: proc(app: ^App) { 	// , ui_manager: ^UIManager) {
	time_manager_capture_frame_start(&app.time_manager)

	for e: SDL.Event; SDL.PollEvent(&e); {
		// ui_manager_process_event(ui_manager, e)

		#partial switch e.type {
		case .QUIT:
			app.quit = true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			lw, lh, pw, ph: i32
			SDL.GetWindowSizeInPixels(app.window, &pw, &ph)
			SDL.GetWindowSize(app.window, &lw, &lh)

			app.window_info.pixel_width = cast(int)pw
			app.window_info.pixel_height = cast(int)ph
			app.window_info.logical_width = cast(int)lw
			app.window_info.logical_height = cast(int)lh

			app.window_info.pixel_ratio =
				f32(app.window_info.pixel_width) / f32(app.window_info.logical_width)
			renderer_resize(
				app.renderer,
				app.window_info.logical_width,
				app.window_info.logical_height,
				app.window_info.pixel_width,
				app.window_info.pixel_height,
			)
		case .DROP_FILE:
			drop := e.drop
			fmt.println(drop.data)
			texture_create(app.renderer, string(drop.data), "tmp")
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
	renderer_delete(app.renderer)
	free(app.renderer)
	delete_map(app.key_callbacks)

	SDL.DestroyWindow(app.window)
	SDL.Quit()

	free(app)
}
