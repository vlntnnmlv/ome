package omeapi

import "core:c"

import LUA "vendor:lua/5.4"

import "ome:assets"
import "ome:core"
import "ome:render"

@(private)
l_rect :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	render.rect(host.renderer, arg_rect(L, 1), arg_color(L, 5, core.WHITE))
	return 0
}

@(private)
l_outline :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	rect := arg_rect(L, 1)
	color := arg_color(L, 5, core.WHITE)
	thickness := int(LUA.L_optinteger(L, 6, 1))
	render.quad(host.renderer, rect, color, thickness)
	return 0
}

@(private)
l_line :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	a := [2]f32{arg_f32(L, 1), arg_f32(L, 2)}
	b := [2]f32{arg_f32(L, 3), arg_f32(L, 4)}
	color := arg_color(L, 5, core.WHITE)
	thickness := int(LUA.L_optinteger(L, 6, 1))
	render.line(host.renderer, a, b, color, thickness)
	return 0
}

@(private)
l_text :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	text := arg_string(L, 1)
	rect := arg_rect(L, 2)
	size := u32(max(LUA.L_optinteger(L, 6, 32), 1))
	color := arg_color(L, 7, core.WHITE)

	font_handle := host.default_font_handle
	if !LUA.isnoneornil(L, 8) {
		found: bool
		font_handle, found = assets.library_find_font(host.library, arg_string(L, 8))
		if !found {
			return LUA.L_argerror(L, 8, "unknown font")
		}
	}

	render.text(host.renderer, text, font_handle, size, rect, color)
	return 0
}

@(private)
l_sprite :: proc "c" (L: ^LUA.State) -> c.int {
	host := host(L)
	context = host.ctx
	atlas_handle, found := assets.library_find_atlas(host.library, arg_string(L, 1))
	if !found {
		return LUA.L_argerror(L, 1, "unknown atlas")
	}

	sprite := arg_string(L, 2)
	rect := arg_rect(L, 3)
	color := arg_color(L, 7, core.WHITE)
	slice := arg_slice(L, 8)
	render.texture_by_atlas_name(host.renderer, atlas_handle, sprite, rect, color, slice)
	return 0
}
