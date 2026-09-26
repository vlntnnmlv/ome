#+build darwin
package omeplatform

import SDL "vendor:sdl3"

window_native_handle :: proc(window: ^Window) -> NativeWindowHandle {
	return NativeWindowHandle(
		SDL.GetPointerProperty(
			SDL.GetWindowProperties(window.native),
			SDL.PROP_WINDOW_COCOA_WINDOW_POINTER,
			nil,
		),
	)
}

window_pre_init :: proc() {
	environment := SDL.GetEnvironment()
	SDL.SetEnvironmentVariable(environment, "METAL_DEVICE_WRAPPER_TYPE", "1", false)
}
