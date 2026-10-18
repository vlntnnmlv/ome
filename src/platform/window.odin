package omeplatform

import "core:log"
import "vendor:vulkan"

import SDL "vendor:sdl3"

WindowInfo :: struct {
	logical_height: f32,
	logical_width:  f32,
	pixel_width:    f32,
	pixel_height:   f32,
	pixel_ratio:    f32,
}

Window :: struct {
	native: ^SDL.Window,
	info:   WindowInfo,
}

window_create :: proc(title: cstring, logical_width, logical_height: i32) -> (^Window, bool) {
	if ok := SDL.InitSubSystem({.VIDEO}); !ok {
		log.errorf(
			"platform/window: sdl video subsystem failed to initialize with error %v",
			SDL.GetError(),
		)
		SDL.QuitSubSystem({.VIDEO})
		return nil, false
	}

	native := SDL.CreateWindow(
		title,
		logical_width,
		logical_height,
		{.HIGH_PIXEL_DENSITY, .HIDDEN, .RESIZABLE, .VULKAN},
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

window_create_surface :: proc(
	window: ^Window,
	instance: vulkan.Instance,
) -> (
	vulkan.SurfaceKHR,
	bool,
) {
	surface: vulkan.SurfaceKHR
	if !SDL.Vulkan_CreateSurface(window.native, instance, nil, &surface) {
		log.errorf("platform/window: vulkan surface creation failed with error %v", SDL.GetError())
		return 0, false
	}

	return surface, true
}

window_refresh_info :: proc(window: ^Window) {
	logical_width, logical_height, pixel_width, pixel_height: i32
	SDL.GetWindowSize(window.native, &logical_width, &logical_height)
	SDL.GetWindowSizeInPixels(window.native, &pixel_width, &pixel_height)

	window.info = WindowInfo {
		logical_width  = f32(logical_width),
		logical_height = f32(logical_height),
		pixel_width    = f32(pixel_width),
		pixel_height   = f32(pixel_height),
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

vulkan_instance_proc_address :: proc() -> rawptr {
	return rawptr(SDL.Vulkan_GetVkGetInstanceProcAddr())
}

vulkan_instance_extensions :: proc() -> []cstring {
	count: u32
	names := SDL.Vulkan_GetInstanceExtensions(&count)
	return names[:count]
}
