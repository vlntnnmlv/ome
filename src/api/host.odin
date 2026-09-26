package omeapi

import "base:runtime"
import "core:mem"
import "core:reflect"
import "core:strings"

import LUA "vendor:lua/5.4"

import "ome:assets"
import "ome:core"
import "ome:platform"
import "ome:render"
import "ome:script"

Host :: struct {
	ctx:                 runtime.Context,
	allocator:           mem.Allocator,
	renderer:            ^render.Renderer,
	library:             ^assets.Library,
	window:              ^platform.Window,
	clock:               ^core.Clock,
	default_font_handle: assets.FontHandle,
	keys:                map[string]platform.Key,
}

host_create :: proc(
	renderer: ^render.Renderer,
	window: ^platform.Window,
	clock: ^core.Clock,
	default_font_handle: assets.FontHandle,
	allocator: mem.Allocator = context.allocator,
) -> ^Host {
	host := new(Host, allocator)

	host.ctx = context
	host.allocator = allocator
	host.renderer = renderer
	host.library = renderer.library
	host.window = window
	host.clock = clock
	host.default_font_handle = default_font_handle

	names := reflect.enum_field_names(platform.Key)
	values := reflect.enum_field_values(platform.Key)
	host.keys = make(map[string]platform.Key, len(names), allocator)
	for name, i in names {
		host.keys[strings.to_lower(name, allocator)] = platform.Key(values[i])
	}

	return host
}

host_register :: proc(host: ^Host, vm: ^script.VM) {
	L := vm.state

	funcs := [?]LUA.L_Reg {
		{"rect", l_rect},
		{"outline", l_outline},
		{"line", l_line},
		{"text", l_text},
		{"sprite", l_sprite},
		{"key_down", l_key_down},
		{"key_pressed", l_key_pressed},
		{"mouse", l_mouse},
		{"mouse_down", l_mouse_down},
		{"mouse_pressed", l_mouse_pressed},
		{"screen", l_screen},
		{"time", l_time},
		{nil, nil},
	}

	LUA.createtable(L, 0, len(funcs) - 1)
	LUA.pushlightuserdata(L, host)
	LUA.L_setfuncs(L, raw_data(funcs[:]), 1)
	LUA.setglobal(L, "ome")
}

host_destroy :: proc(host: ^Host) {
	for name in host.keys {
		delete(name, host.allocator)
	}

	delete(host.keys)
	free(host, host.allocator)
}

@(private)
host :: proc "contextless" (L: ^LUA.State) -> ^Host {
	return (^Host)(LUA.touserdata(L, LUA.REGISTRYINDEX - 1))
}
