package omeapp

import "ome:assets"
import "ome:core"
import "ome:gpu"
import "ome:platform"
import "ome:render"

Engine :: struct {
	window:         ^platform.Window,
	renderer:       ^render.Renderer,
	event_handlers: [dynamic]EventHandler,
	key_callbacks:  map[platform.Key]KeyCallback,
	quit:           bool,
	frame_open:     bool,
	clock:          core.Clock,
	frame_skipped:  bool,
}

EventHandler :: struct {
	user_data: rawptr,
	on_event:  proc(data: rawptr, event: platform.Event) -> bool,
}

KeyCallback :: proc(engine: ^Engine)

engine_create :: proc(
	title: cstring,
	logical_width, logical_height: i32,
	clear_color: core.Color = {0, 34, 44, 255},
) -> (
	^Engine,
	bool,
) {
	window, window_ok := platform.window_create(title, logical_width, logical_height)
	if !window_ok {
		return nil, false
	}

	device, device_ok := gpu.device_create(
		platform.window_native_handle(window),
		window.info,
		core.color_to_linear64(clear_color),
	)
	if !device_ok {
		platform.window_destroy(window)
		return nil, false
	}

	engine := new(Engine)
	engine.window = window

	library := assets.library_create(device)
	engine.renderer = render.renderer_create(device, library, engine.window.info)

	engine.key_callbacks = make(map[platform.Key]KeyCallback)
	engine.event_handlers = make([dynamic]EventHandler)

	engine.quit = false
	core.clock_start(&engine.clock)

	platform.window_show(window)

	return engine, true
}

engine_add_event_handler :: proc(
	engine: ^Engine,
	user_data: rawptr,
	on_event: proc(user_data: rawptr, event: platform.Event) -> bool,
) -> bool {
	_, err := append(&engine.event_handlers, EventHandler{user_data, on_event})
	return err == nil
}

@(private)
engine_broadcast_event :: proc(engine: ^Engine, event: platform.Event) {
	for handler in engine.event_handlers {
		_ = handler.on_event(handler.user_data, event)
	}
}

@(private)
engine_offer_event :: proc(engine: ^Engine, event: platform.Event) -> bool {
	for handler in engine.event_handlers {
		if handler.on_event(handler.user_data, event) {
			return true
		}
	}
	return false
}

@(private)
engine_process_events :: proc(engine: ^Engine) {
	core.clock_capture_frame_start(&engine.clock)

	for event in platform.event_poll(engine.window) {
		switch e in event {
		case platform.QuitEvent:
			engine.quit = true
			engine_broadcast_event(engine, event)
		case platform.ResizeEvent:
			render.renderer_resize(engine.renderer, engine.window.info)
			engine_broadcast_event(engine, event)
		case platform.DropFileEvent:
			engine_broadcast_event(engine, event)
		case platform.KeyEvent:
			if engine_offer_event(engine, event) {
				break
			}

			if e.down {
				if e.key == .Escape {
					engine.quit = true
				}
				if callback, ok := engine.key_callbacks[e.key]; ok {
					callback(engine)
				}
			}
		case platform.MouseMoveEvent:
			engine_offer_event(engine, event)
		case platform.MouseButtonEvent:
			engine_offer_event(engine, event)
		case platform.MouseWheelEvent:
			engine_offer_event(engine, event)
		case platform.MouseLeaveEvent:
			engine_offer_event(engine, event)
		}
	}
}

@(private)
engine_end_frame :: proc(engine: ^Engine) {
	if !engine.frame_skipped {
		render.renderer_flush(engine.renderer)
		render.renderer_present(engine.renderer)
	}
	core.clock_update(&engine.clock)

	free_all(context.temp_allocator)
	engine.frame_open = false
}

engine_next_frame :: proc(engine: ^Engine) -> bool {
	if engine.frame_open {
		engine_end_frame(engine)
	}

	engine_process_events(engine)

	platform.input_update()

	if engine.quit {
		return false
	}

	engine.frame_skipped = !render.renderer_begin(engine.renderer)
	engine.frame_open = true
	return engine.frame_open
}

engine_destroy :: proc(engine: ^Engine) {
	if engine.frame_open {
		engine_end_frame(engine)
	}

	renderer := engine.renderer
	device := renderer.device
	library := renderer.library

	gpu.device_wait_idle(device)
	render.renderer_destroy(renderer)
	assets.library_destroy(library)
	gpu.device_destroy(device)

	delete(engine.key_callbacks)
	delete(engine.event_handlers)

	platform.window_destroy(engine.window)
	free(engine)
}
