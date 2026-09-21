package omeplatform

import "core:log"

import SDL "vendor:sdl3"

NativeWindowHandle :: distinct rawptr

WindowInfo :: struct {
	logical_height: int,
	logical_width:  int,
	pixel_width:    int,
	pixel_height:   int,
	pixel_ratio:    f32,
}

Window :: struct {
	handle: ^SDL.Window,
	info:   WindowInfo,
}

window_create :: proc(title: cstring, logical_width, logical_height: i32) -> (^Window, bool) {
	environment := SDL.GetEnvironment()
	SDL.SetEnvironmentVariable(environment, "METAL_DEVICE_WRAPPER_TYPE", "1", false)

	if ok := SDL.InitSubSystem({.VIDEO}); !ok {
		log.errorf("SDL Video subsystem couldn't initialize: %v", SDL.GetError())
		return nil, false
	}

	handle := SDL.CreateWindow(
		title,
		logical_width,
		logical_height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE},
	)

	if handle == nil {
		log.errorf("SDL window couldn't initialize: %v", SDL.GetError())
		return nil, false
	}

	window := new(Window)
	window.handle = handle
	window_refresh_info(window)
	return window, true
}

window_refresh_info :: proc(window: ^Window) {
	logical_width, logical_height, pixel_width, pixel_height: i32
	SDL.GetWindowSize(window.handle, &logical_width, &logical_height)
	SDL.GetWindowSizeInPixels(window.handle, &pixel_width, &pixel_height)

	window.info = WindowInfo {
		logical_width  = int(logical_width),
		logical_height = int(logical_height),
		pixel_width    = int(pixel_width),
		pixel_height   = int(pixel_height),
		pixel_ratio    = f32(pixel_width) / f32(logical_width),
	}
}

window_show :: proc(window: ^Window) {
	SDL.ShowWindow(window.handle)
}

window_destroy :: proc(window: ^Window) {
	SDL.DestroyWindow(window.handle)
	SDL.Quit()
	free(window)
}
