package omeapi

import "core:c"
import lua "vendor:lua/5.4"

import "ome:assets"
import "ome:core"
import "ome:render"

@(private)
l_rect :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	render.rect(h.renderer, arg_rect(L, 1), arg_color(L, 5, core.WHITE))
	return 0
}

@(private)
l_outline :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	rect := arg_rect(L, 1)
	color := arg_color(L, 5, core.WHITE)
	thickness := int(lua.L_optinteger(L, 6, 1))
	render.quad(h.renderer, rect, color, thickness, false)
	return 0
}


@(private)
l_line :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	a := [2]f32{arg_f32(L, 1), arg_f32(L, 2)}
	b := [2]f32{arg_f32(L, 3), arg_f32(L, 4)}
	color := arg_color(L, 5, core.WHITE)
	thickness := int(lua.L_optinteger(L, 6, 1))
	render.line(h.renderer, a, b, color, thickness)
	return 0
}

@(private)
l_text :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	text := arg_string(L, 1)
	rect := arg_rect(L, 2)
	size := u32(max(lua.L_optinteger(L, 6, 32), 1))
	color := arg_color(L, 7, core.WHITE)

	font := h.font_default
	if !lua.isnoneornil(L, 8) {
		found: bool
		font, found = assets.font_by_name(h.assets_i, arg_string(L, 8))
		if !found do return lua.L_argerror(L, 8, "unknown font")
	}

	render.text(h.renderer, text, font, size, rect, color)
	return 0
}

@(private)
l_sprite :: proc "c" (L: ^lua.State) -> c.int {
	h := host(L)
	context = h.ctx
	atlas, found := assets.atlas_by_name(h.assets_i, arg_string(L, 1))
	if !found do return lua.L_argerror(L, 1, "unknown atlas")
	sprite := arg_string(L, 2)
	rect := arg_rect(L, 3)
	color := arg_color(L, 7, core.WHITE)
	slice := arg_slice(L, 8)
	render.texture_by_atlas_name(h.renderer, atlas, sprite, rect, color, slice)
	return 0
}
