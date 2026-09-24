package omeapi

import "base:runtime"
import "core:mem"
import "core:reflect"
import "core:strings"
import lua "vendor:lua/5.4"

import "ome:assets"
import "ome:core"
import "ome:platform"
import "ome:render"
import "ome:script"

Instance :: struct {
	ctx:          runtime.Context,
	allocator:    mem.Allocator,
	renderer:     ^render.Renderer,
	assets_i:     ^assets.Instance,
	window:       ^platform.Window,
	clock:        ^core.Clock,
	font_default: assets.FontHandle,
	keys:         map[string]platform.Key,
}

instance :: proc(
	renderer: ^render.Renderer,
	window: ^platform.Window,
	clock: ^core.Clock,
	font_default: assets.FontHandle,
	allocator: mem.Allocator = context.allocator,
) -> ^Instance {
	instance := new(Instance, allocator)

	instance.ctx = context
	instance.allocator = allocator
	instance.renderer = renderer
	instance.assets_i = renderer.assets
	instance.window = window
	instance.clock = clock
	instance.font_default = font_default

	names := reflect.enum_field_names(platform.Key)
	values := reflect.enum_field_values(platform.Key)
	instance.keys = make(map[string]platform.Key, len(names), allocator)
	for name, i in names {
		instance.keys[strings.to_lower(name, allocator)] = platform.Key(values[i])
	}

	return instance
}

register :: proc(instance: ^Instance, script_i: ^script.Instance) {
	L := script_i.state

	funcs := [?]lua.L_Reg {
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

	lua.createtable(L, 0, len(funcs) - 1)
	lua.pushlightuserdata(L, instance)
	lua.L_setfuncs(L, raw_data(funcs[:]), 1)
	lua.setglobal(L, "ome")
}

destroy :: proc(instance: ^Instance) {
	for name in instance.keys do delete(name, instance.allocator)
	delete(instance.keys)
	free(instance, instance.allocator)
}

@(private)
host :: proc "contextless" (L: ^lua.State) -> ^Instance {
	return (^Instance)(lua.touserdata(L, lua.REGISTRYINDEX - 1))
}
