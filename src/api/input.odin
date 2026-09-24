package omeapi

import "core:c"
import lua "vendor:lua/5.4"

import "ome:platform"

@(private)
arg_key :: proc(L: ^lua.State, h: ^Instance, idx: c.int) -> platform.Key {
	key, found := h.keys[arg_string(L, idx)]
	if !found do lua.L_argerror(L, idx, "unknown key")
	return key
}

@(private)
arg_button :: proc(L: ^lua.State, idx: c.int) -> platform.MouseButton {
	if lua.isnoneornil(L, idx) do return .Left
	switch arg_string(L, idx) {
	case "left":
		return .Left
	case "right":
		return .Right
	case "middle":
		return .Middle
	}
	lua.L_argerror(L, idx, "expected 'left', 'right' or 'middle'")
	return .Unknown
}

@(private)
l_key_down :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	lua.pushboolean(L, b32(platform.key_down(arg_key(L, h, 1))))
	return 1
}

@(private)
l_key_pressed :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	lua.pushboolean(L, b32(platform.key_pressed(arg_key(L, h, 1))))
	return 1
}

@(private)
l_mouse :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	p := platform.mouse_position()
	lua.pushnumber(L, lua.Number(p.x))
	lua.pushnumber(L, lua.Number(p.y))
	return 2
}

@(private)
l_mouse_down :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	lua.pushboolean(L, b32(platform.mouse_button_down(arg_button(L, 1))))
	return 1
}

@(private)
l_mouse_pressed :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	lua.pushboolean(L, b32(platform.mouse_button_pressed(arg_button(L, 1))))
	return 1
}

@(private)
l_screen :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	lua.pushinteger(L, lua.Integer(h.window.info.logical_width))
	lua.pushinteger(L, lua.Integer(h.window.info.logical_height))
	return 2
}

@(private)
l_time :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	lua.pushnumber(L, lua.Number(h.clock.time))
	return 1
}
