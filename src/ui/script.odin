package omeui

import "core:log"
import "core:mem"
import "core:time"

import "ome:assets"
import "ome:core"
import "ome:script"

LuaView :: struct {
	path:          string,
	scene_handle:  SceneHandle,
	parent_handle: PanelHandle,
	root_handle:   PanelHandle,
	mtime:         time.Time,
}

@(private)
panel_flat_from_lua_file :: proc(
	script_instance: ^script.Instance,
	assets_instanse: ^assets.Instance,
	path: string,
	allocator: mem.Allocator,
) -> (
	PanelFlat,
	bool,
) {
	if err, msg := script.run_file(script_instance, path); err != .None {
		log.errorf("ui/lua: %s: %v: %s", path, err, msg)
		return {}, false
	}
	defer script.clear_stack(script_instance)

	top := script.abs_index(script_instance, -1)
	if !script.is_table(script_instance, top) {
		log.errorf("ui/lua: %s must return a table", path)
		return {}, false
	}

	return panel_flat_from_lua(script_instance, assets_instanse, top, allocator)
}

scene_load_lua :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	script_instance: ^script.Instance,
	assets_instance: ^assets.Instance,
	path: string,
	allocator: mem.Allocator = context.allocator,
) -> (
	PanelHandle,
	bool,
) {
	flat, ok := panel_flat_from_lua_file(
		script_instance,
		assets_instance,
		path,
		context.temp_allocator,
	)
	if !ok do return EMPTY_HANDLE, false

	return panel_unflatten(scene, parent_handle, flat, allocator), true
}

@(private)
panel_flat_from_lua :: proc(
	s: ^script.Instance,
	a: ^assets.Instance,
	index: i32,
	allocator: mem.Allocator,
) -> (
	flat: PanelFlat,
	ok: bool,
) {
	idx := script.abs_index(s, index)

	name, _ := script.field_string(s, idx, "name", "unnamed", allocator)

	r: [4]f32
	if !script.field_numbers(s, idx, "rect", r[:]) {
		log.warnf("ui/lua: panel '%s' has no valid rect", name)
		return {}, false
	}

	spec, spec_ok := spec_from_lua(s, a, idx, allocator)
	if !spec_ok do return {}, false

	flat = PanelFlat {
		name     = name,
		rect     = core.Rect{r[0], r[1], r[2], r[3]},
		spec     = spec,
		children = make([dynamic]PanelFlat, allocator),
	}

	if script.push_field(s, idx, "children") {
		defer script.pop(s)

		children := script.abs_index(s, -1)
		for i in 1 ..= script.array_len(s, children) {
			if !script.push_index(s, children, i) do continue
			child, child_ok := panel_flat_from_lua(s, a, -1, allocator)
			script.pop(s)
			if child_ok do append(&flat.children, child)
		}
	}

	return flat, true
}

@(private)
spec_from_lua :: proc(
	s: ^script.Instance,
	a: ^assets.Instance,
	index: i32,
	allocator: mem.Allocator,
) -> (
	Spec,
	bool,
) {
	kind, _ := script.field_string(s, index, "kind", "panel", allocator)

	color := core.Color{255, 255, 255, 255}
	c: [4]f32
	if script.field_numbers(s, index, "color", c[:]) {
		color = core.Color{u8(c[0]), u8(c[1]), u8(c[2]), u8(c[3])}
	}

	switch kind {
	case "panel":
		return PanelSpec{color = color}, true

	case "image":
		atlas_name, has_atlas := script.field_string(s, index, "atlas", "", allocator)
		sprite_name, has_sprite := script.field_string(s, index, "sprite", "", allocator)
		if !has_atlas || !has_sprite {
			log.warn("ui/lua: image panel needs 'atlas' and 'sprite'")
			return nil, false
		}

		atlas_handle, found := assets.atlas_by_name(a, atlas_name)
		if !found {
			log.warnf("ui/lua: unknown atlas '%s'", atlas_name)
			return nil, false
		}

		offset: core.RectOffset
		slice: [4]f32
		if script.field_numbers(s, index, "slice", slice[:]) {
			// RectOffset is {left, right, top, bottom}
			offset = core.RectOffset{slice[0], slice[1], slice[2], slice[3]}
		}

		return ImageSpec {
				panel = PanelSpec{color = color},
				atlas_handle = atlas_handle,
				sprite_name = sprite_name,
				slice_offset = offset,
			},
			true

	case "text":
		text, has_text := script.field_string(s, index, "text", "", allocator)
		font_name, has_font := script.field_string(s, index, "font", "", allocator)
		if !has_text || !has_font {
			log.warn("ui/lua: text panel needs 'text' and 'font'")
			return nil, false
		}

		font_handle, found := assets.font_by_name(a, font_name)
		if !found {
			log.warnf("ui/lua: unknown font '%s'", font_name)
			return nil, false
		}

		size, _ := script.field_number(s, index, "size", 32)

		return TextSpec {
				panel = PanelSpec{color = color},
				text = text,
				font_handle = font_handle,
				font_size = u32(size),
			},
			true
	}

	log.warnf("ui/lua: unknown kind '%s'", kind)
	return nil, false
}
