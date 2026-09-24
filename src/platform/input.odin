package omeplatform

import "core:c"

import SDL "vendor:sdl3"

@(private = "file")
Input :: struct {
	keys_now, keys_prev:   [Key.Count]bool,
	mouse_now, mouse_prev: [MouseButton]bool,
	mouse_position:        [2]f32,
}

@(private = "file")
input: Input

input_update :: proc() {
	input.keys_prev = input.keys_now
	input.mouse_prev = input.mouse_now

	numkeys: c.int
	if state := SDL.GetKeyboardState(&numkeys); state != nil {
		for i in 0 ..< min(int(numkeys), int(Key.Count)) do input.keys_now[i] = state[i]
	}

	x, y: f32
	flags := SDL.GetMouseState(&x, &y)
	input.mouse_position = {x, y}
	input.mouse_now[.Left] = .LEFT in flags
	input.mouse_now[.Middle] = .MIDDLE in flags
	input.mouse_now[.Right] = .RIGHT in flags
	input.mouse_now[.X1] = .X1 in flags
	input.mouse_now[.X2] = .X2 in flags
}

key_down :: proc(key: Key) -> bool {
	i, ok := key_index(key)
	return ok && input.keys_now[i]
}

key_pressed :: proc(key: Key) -> bool {
	i, ok := key_index(key)
	return ok && input.keys_now[i] && !input.keys_prev[i]
}

key_released :: proc(key: Key) -> bool {
	i, ok := key_index(key)
	return ok && !input.keys_now[i] && input.keys_prev[i]
}

mouse_position :: proc() -> [2]f32 {
	return input.mouse_position
}

mouse_button_down :: proc(button: MouseButton) -> bool {
	return input.mouse_now[button]
}

mouse_button_pressed :: proc(button: MouseButton) -> bool {
	return input.mouse_now[button] && !input.mouse_prev[button]
}

@(private = "file")
key_index :: proc(key: Key) -> (int, bool) {
	i := int(key)
	return i, i > 0 && i < int(Key.Count)
}
