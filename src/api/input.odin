package omeapi

import "core:c"

import LUA "vendor:lua/5.4"

import "ome:platform"

@(private)
arg_key :: proc(L: ^LUA.State, h: ^Host, idx: c.int) -> platform.Key {
	key, found := h.keys[arg_string(L, idx)]
	if !found {
		LUA.L_argerror(L, idx, "unknown key")
	}

	return key
}

@(private)
arg_button :: proc(L: ^LUA.State, idx: c.int) -> platform.MouseButton {
	if LUA.isnoneornil(L, idx) {
		return .Left
	}

	switch arg_string(L, idx) {
	case "left":
		return .Left
	case "right":
		return .Right
	case "middle":
		return .Middle
	}
	LUA.L_argerror(L, idx, "expected 'left', 'right' or 'middle'")
	return .Unknown
}

@(private)
l_key_down :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	LUA.pushboolean(L, b32(platform.key_down(arg_key(L, host, 1))))
	return 1
}

@(private)
l_key_pressed :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	LUA.pushboolean(L, b32(platform.key_pressed(arg_key(L, host, 1))))
	return 1
}

@(private)
l_mouse :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	position := platform.mouse_position()
	LUA.pushnumber(L, LUA.Number(position.x))
	LUA.pushnumber(L, LUA.Number(position.y))
	return 2
}

@(private)
l_mouse_down :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	LUA.pushboolean(L, b32(platform.mouse_button_down(arg_button(L, 1))))
	return 1
}

@(private)
l_mouse_pressed :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	LUA.pushboolean(L, b32(platform.mouse_button_pressed(arg_button(L, 1))))
	return 1
}

@(private)
l_screen :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	LUA.pushinteger(L, LUA.Integer(host.window.info.logical_width))
	LUA.pushinteger(L, LUA.Integer(host.window.info.logical_height))
	return 2
}

@(private)
l_time :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	LUA.pushnumber(L, LUA.Number(host.clock.time))
	return 1
}
