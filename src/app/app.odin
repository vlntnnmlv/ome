package omeapp

import "ome:core"
import "ome:core/gpu"
import "ome:core/platform"

App :: struct {
	window:        ^platform.Window,
	renderer:      ^gpu.Renderer,
	key_callbacks: map[platform.Key]KeyCallback,
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

	app.key_callbacks = make(map[platform.Key]KeyCallback)
	app.quit = false
	core.time_manager_start(&app.time_manager)

	platform.window_show(window)

	return app, true
}

app_process_events :: proc(app: ^App) { 	// , ui_manager: ^UIManager) {
	core.time_manager_capture_frame_start(&app.time_manager)

	for event in platform.poll_event(app.window) {
		switch e in event {
		case platform.QuitEvent:
			app.quit = true
		case platform.ResizeEvent:
			gpu.renderer_resize(app.renderer, app.window.info)
		case platform.DropFileEvent:
			gpu.texture_create(app.renderer.bind_table, string(e.path), "tmp")
		case platform.KeyEvent:
			if e.down {
				if e.key == .Escape do app.quit = true
				if callback, ok := app.key_callbacks[e.key]; ok do callback(app)
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
