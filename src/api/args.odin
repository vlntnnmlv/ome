package omeapi

import "core:c"

import LUA "vendor:lua/5.4"

import "ome:core"

@(private)
arg_f32 :: proc(L: ^LUA.State, idx: c.int) -> f32 {
	return f32(LUA.L_checknumber(L, idx))
}

@(private)
arg_rect :: proc(L: ^LUA.State, first: c.int) -> core.Rect {
	return {arg_f32(L, first), arg_f32(L, first + 1), arg_f32(L, first + 2), arg_f32(L, first + 3)}
}

@(private)
arg_string :: proc(L: ^LUA.State, idx: c.int) -> string {
	return string(LUA.L_checkstring(L, idx))
}

@(private)
arg_numbers :: proc(L: ^LUA.State, idx: c.int, out: []f32) -> bool {
	if LUA.isnoneornil(L, idx) {
		return false
	}

	LUA.L_checktype(L, idx, c.int(LUA.Type.TABLE))

	for &o, i in out {
		LUA.rawgeti(L, idx, LUA.Integer(i + 1))
		is_number: b32
		n := LUA.tonumber(L, -1, &is_number)
		LUA.pop(L, 1)
		if is_number {
			o = f32(n)
		}
	}
	return true
}

@(private)
arg_color :: proc(L: ^LUA.State, idx: c.int, fallback: core.Color) -> core.Color {
	v := [4]f32{0, 0, 0, 255} // {r, g, b} gets alpha 255
	if !arg_numbers(L, idx, v[:]) {
		return fallback
	}

	return core.color_clamp(v)
}

@(private)
arg_slice :: proc(L: ^LUA.State, idx: c.int) -> core.RectOffset {
	v: [4]f32
	if !arg_numbers(L, idx, v[:]) {
		return core.ZERO_RECT_OFFSET
	}

	return core.RectOffset{v[0], v[1], v[2], v[3]}
}
