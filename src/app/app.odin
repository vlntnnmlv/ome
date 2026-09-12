package omeapp

import "core:log"
import "ome:core"
import "ome:core/gpu"
import "ome:core/platform"
import "ome:core/render"
import "ome:core/resources"

App :: struct {
	window:        ^platform.Window,
	renderer:      ^render.Renderer,
	key_callbacks: map[platform.Key]KeyCallback,
	quit:          bool,
	frame_open:    bool,
	time_manager:  core.TimeManager,
}

KeyCallback :: proc(ctx: ^App)

create :: proc(
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

	device, device_ok := gpu.device_create(
		platform.window_native_handle(app.window),
		app.window.info,
		core.color_to_linear64(clear_color),
	)
	if !device_ok {
		log.error("Couldn't create GPU device!")
		return nil, false
	}

	assets := resources.create(device)
	app.renderer = render.create(device, assets, app.window.info)

	app.key_callbacks = make(map[platform.Key]KeyCallback)
	app.quit = false
	core.time_manager_start(&app.time_manager)

	platform.window_show(window)

	return app, true
}

@(private)
process_events :: proc(app: ^App) {
	core.time_manager_capture_frame_start(&app.time_manager)

	for event in platform.poll_event(app.window) {
		switch e in event {
		case platform.QuitEvent:
			app.quit = true
		case platform.ResizeEvent:
			render.resize(app.renderer, app.window.info)
		case platform.DropFileEvent:
			resources.load_texture(app.renderer.assets, string(e.path), "tmp")
		case platform.KeyEvent:
			if e.down {
				if e.key == .Escape do app.quit = true
				if callback, ok := app.key_callbacks[e.key]; ok do callback(app)
			}
		}
	}
}

@(private)
frame_close :: proc(app: ^App) {
	render.flush(app.renderer)
	render.present(app.renderer)
	core.time_manager_update(&app.time_manager)

	free_all(context.temp_allocator)
	app.frame_open = false
}

frame :: proc(app: ^App) -> bool {
	if app.frame_open do frame_close(app)

	process_events(app)
	if app.quit do return false

	render.begin(app.renderer)
	app.frame_open = true
	return app.frame_open
}

close :: proc(app: ^App) {
	if app.frame_open do frame_close(app)

	render.delete(app.renderer)
	platform.window_destroy(app.window)
	free(app)
}
