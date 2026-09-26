#+build linux
package omeplatform

window_native_handle :: proc(window: ^Window) -> NativeWindowHandle {
	panic("Not implemented")
}

window_pre_init :: proc() {
	panic("Not implemented")
}
