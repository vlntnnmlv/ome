package omeapp

import "core:fmt"

import SDL "vendor:sdl3"

import "ome:core"
import "ome:core/gpu"
import "ome:core/platform"

App :: struct {
	window:        ^platform.Window,
	renderer:      ^gpu.Renderer,
	key_callbacks: map[u64]KeyCallback,
	quit:          bool,
	time_manager:  core.TimeManager,
}

KeyCallback :: proc(ctx: ^App)
app_create :: proc(
	title: cstring,
	logical_width, logical_height: i32,
	clear_color: core.Color = {0, 34, 44, 255},
) -> (
	^App,
	bool,
) {
	window, window_ok := platform.window_create(title, logical_width, logical_height)
	if !window_ok do return nil, false

	app := new(App)
	app.window = window

	if renderer, ok := gpu.renderer_create(
		platform.window_native_handle(app.window),
		app.window.info,
		core.color_to_linear64(clear_color),
	); !ok {
		return nil, false
	} else {
		app.renderer = renderer
	}

	app.key_callbacks = make(map[u64]KeyCallback)
	app.quit = false
	core.time_manager_start(&app.time_manager)

	platform.window_show(window)

	return app, true
}

app_process_events :: proc(app: ^App) { 	// , ui_manager: ^UIManager) {
	core.time_manager_capture_frame_start(&app.time_manager)

	for e: SDL.Event; SDL.PollEvent(&e); {
		// ui_manager_process_event(ui_manager, e)

		#partial switch e.type {
		case .QUIT:
			app.quit = true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			lw, lh, pw, ph: i32
			SDL.GetWindowSizeInPixels(app.window.handle, &pw, &ph)
			SDL.GetWindowSize(app.window.handle, &lw, &lh)

			app.window.info.pixel_width = cast(int)pw
			app.window.info.pixel_height = cast(int)ph
			app.window.info.logical_width = cast(int)lw
			app.window.info.logical_height = cast(int)lh

			app.window.info.pixel_ratio =
				f32(app.window.info.pixel_width) / f32(app.window.info.logical_width)
			gpu.renderer_resize(app.renderer, app.window.info)
		case .DROP_FILE:
			drop := e.drop
			fmt.println(drop.data)
			gpu.texture_create(app.renderer.bind_table, string(drop.data), "tmp")
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
	gpu.renderer_begin(app.renderer)
}

app_render :: proc(app: ^App) {
	gpu.renderer_flush(app.renderer)
}

app_submit :: proc(app: ^App) {
	gpu.renderer_present(app.renderer)
	core.time_manager_update(&app.time_manager)
}

app_close :: proc(app: ^App) {
	gpu.renderer_delete(app.renderer)
	free(app.renderer)
	delete_map(app.key_callbacks)

	platform.window_destroy(app.window)
	free(app)
}
