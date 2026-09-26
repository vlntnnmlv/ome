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
	native: ^SDL.Window,
	info:   WindowInfo,
}

window_create :: proc(title: cstring, logical_width, logical_height: i32) -> (^Window, bool) {
	window_pre_init()

	if ok := SDL.InitSubSystem({.VIDEO}); !ok {
		log.errorf(
			"platform/window: sdl video subsystem failed to initialize woth error %v",
			SDL.GetError(),
		)
		return nil, false
	}

	native := SDL.CreateWindow(
		title,
		logical_width,
		logical_height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE},
	)

	if native == nil {
		log.errorf(
			"platform/window: sdl window failed to initialize with error %v",
			SDL.GetError(),
		)
		return nil, false
	}

	window := new(Window)
	window.native = native
	window_refresh_info(window)
	return window, true
}

window_refresh_info :: proc(window: ^Window) {
	logical_width, logical_height, pixel_width, pixel_height: i32
	SDL.GetWindowSize(window.native, &logical_width, &logical_height)
	SDL.GetWindowSizeInPixels(window.native, &pixel_width, &pixel_height)

	window.info = WindowInfo {
		logical_width  = int(logical_width),
		logical_height = int(logical_height),
		pixel_width    = int(pixel_width),
		pixel_height   = int(pixel_height),
		pixel_ratio    = f32(pixel_width) / f32(logical_width),
	}
}

window_show :: proc(window: ^Window) {
	SDL.ShowWindow(window.native)
}

window_destroy :: proc(window: ^Window) {
	SDL.DestroyWindow(window.native)
	SDL.Quit()
	free(window)
}
