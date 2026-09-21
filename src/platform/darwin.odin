package omeplatform

import SDL "vendor:sdl3"

window_native_handle :: proc(window: ^Window) -> NativeWindowHandle {
	return NativeWindowHandle(
		SDL.GetPointerProperty(
			SDL.GetWindowProperties(window.handle),
			SDL.PROP_WINDOW_COCOA_WINDOW_POINTER,
			nil,
		),
	)
}
