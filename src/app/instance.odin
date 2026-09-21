package omeapp

import "core:log"
import "core:mem"
import "ome:assets"
import "ome:core"
import "ome:gpu"
import "ome:platform"
import "ome:render"

Instance :: struct {
	window:         ^platform.Window,
	renderer:       ^render.Renderer,
	event_handlers: [dynamic]EventHandler,
	key_callbacks:  map[platform.Key]KeyCallback,
	quit:           bool,
	frame_open:     bool,
	clock:          core.Clock,
}

EventHandler :: struct {
	user_data: rawptr,
	on_event:  proc(data: rawptr, event: platform.Event) -> bool,
}

KeyCallback :: proc(instance: ^Instance)

instance :: proc(
	title: cstring,
	logical_width, logical_height: i32,
	clear_color: core.Color = {0, 34, 44, 255},
) -> (
	^Instance,
	bool,
) {
	window, window_ok := platform.window_create(title, logical_width, logical_height)
	if !window_ok do return nil, false

	instance := new(Instance)
	instance.window = window

	device, device_ok := gpu.device_create(
		platform.window_native_handle(instance.window),
		instance.window.info,
		core.color_to_linear64(clear_color),
	)
	if !device_ok {
		log.error("Couldn't create GPU device!")
		return nil, false
	}

	assets := assets.instance(device)
	instance.renderer = render.create(device, assets, instance.window.info)

	instance.key_callbacks = make(map[platform.Key]KeyCallback)
	instance.event_handlers = make([dynamic]EventHandler)

	instance.quit = false
	core.clock_start(&instance.clock)

	platform.window_show(window)

	return instance, true
}

add_event_handler :: proc(
	instance: ^Instance,
	user_data: rawptr,
	on_event: proc(user_data: rawptr, event: platform.Event) -> bool,
) -> bool {
	_, err := append(&instance.event_handlers, EventHandler{user_data, on_event})
	return err == mem.Allocator_Error.None
}

@(private)
broadcast_event :: proc(instance: ^Instance, event: platform.Event) {
	for handler in instance.event_handlers {
		_ = handler.on_event(handler.user_data, event)
	}
}

@(private)
offer_event :: proc(instance: ^Instance, event: platform.Event) -> bool {
	for handler in instance.event_handlers {
		if handler.on_event(handler.user_data, event) do return true
	}
	return false
}

@(private)
process_events :: proc(instance: ^Instance) {
	core.clock_capture_frame_start(&instance.clock)

	for event in platform.poll_event(instance.window) {
		switch e in event {
		case platform.QuitEvent:
			instance.quit = true
			broadcast_event(instance, event)
		case platform.ResizeEvent:
			render.resize(instance.renderer, instance.window.info)
			broadcast_event(instance, event)
		case platform.DropFileEvent:
			assets.load_texture(instance.renderer.assets, string(e.path), "tmp")
			broadcast_event(instance, event)
		case platform.KeyEvent:
			if offer_event(instance, event) do break
			if e.down {
				if e.key == .Escape do instance.quit = true
				if callback, ok := instance.key_callbacks[e.key]; ok do callback(instance)
			}
		case platform.MouseMoveEvent:
			offer_event(instance, event)
		case platform.MouseButtonEvent:
			offer_event(instance, event)
		case platform.MouseWheelEvent:
			offer_event(instance, event)
		}
	}
}

@(private)
frame_end :: proc(instance: ^Instance) {
	render.flush(instance.renderer)
	render.present(instance.renderer)
	core.clock_update(&instance.clock)

	free_all(context.temp_allocator)
	instance.frame_open = false
}

frame :: proc(instance: ^Instance) -> bool {
	if instance.frame_open do frame_end(instance)

	process_events(instance)
	if instance.quit do return false

	render.begin(instance.renderer)
	instance.frame_open = true
	return instance.frame_open
}

destroy :: proc(instance: ^Instance) {
	if instance.frame_open do frame_end(instance)

	delete_map(instance.key_callbacks)
	delete(instance.event_handlers)
	render.destroy(instance.renderer)
	platform.window_destroy(instance.window)
	free(instance)
}
