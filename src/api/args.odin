package omeapi

import "core:c"
import lua "vendor:lua/5.4"

import "ome:core"

@(private)
arg_f32 :: proc(L: ^lua.State, idx: c.int) -> f32 {
	return f32(lua.L_checknumber(L, idx))
}

@(private)
arg_rect :: proc(L: ^lua.State, first: c.int) -> core.Rect {
	return {arg_f32(L, first), arg_f32(L, first + 1), arg_f32(L, first + 2), arg_f32(L, first + 3)}
}

@(private)
arg_string :: proc(L: ^lua.State, idx: c.int) -> string {
	return string(lua.L_checkstring(L, idx))
}

@(private)
arg_numbers :: proc(L: ^lua.State, idx: c.int, out: []f32) -> bool {
	if lua.isnoneornil(L, idx) do return false
	lua.L_checktype(L, idx, c.int(lua.Type.TABLE))

	for &o, i in out {
		lua.rawgeti(L, idx, lua.Integer(i + 1))
		is_number: b32
		n := lua.tonumber(L, -1, &is_number)
		lua.pop(L, 1)
		if is_number do o = f32(n)
	}
	return true
}

@(private)
arg_color :: proc(L: ^lua.State, idx: c.int, fallback: core.Color) -> core.Color {
	v := [4]f32{0, 0, 0, 255} // {r, g, b} gets alpha 255
	if !arg_numbers(L, idx, v[:]) do return fallback
	return core.Color {
		u8(clamp(v[0], 0, 255)),
		u8(clamp(v[1], 0, 255)),
		u8(clamp(v[2], 0, 255)),
		u8(clamp(v[3], 0, 255)),
	}
}

@(private)
arg_slice :: proc(L: ^lua.State, idx: c.int) -> core.RectOffset {
	v: [4]f32
	if !arg_numbers(L, idx, v[:]) do return core.ZERO_RECT_OFFSET
	return core.RectOffset{v[0], v[1], v[2], v[3]} // same order as ui/json.odin
}
