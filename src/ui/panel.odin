package omeui

import "base:builtin"
import "core:encoding/json"
import "core:log"
import "core:mem"
import "core:strings"

import "ome:core"
import "ome:handle_map"
import "ome:render"

PanelHandle :: distinct handle_map.Handle

EMPTY_HANDLE :: PanelHandle{}

Panel :: struct {
	uuid:             string,
	handle:           PanelHandle,
	parent_handle:    PanelHandle,
	children_handles: [dynamic]PanelHandle,
	name:             string,
	rect:             core.Rect,
	spec:             Spec,
	ignore_events:    bool,
	hovered:          bool,
	pressed:          bool,
}

@(private)
PanelFlat :: struct {
	uuid:     string,
	handle:   PanelHandle,
	name:     string,
	rect:     core.Rect,
	spec:     Spec,
	children: [dynamic]PanelFlat,
}

panel_create :: proc(
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator := context.allocator,
) -> Panel {
	return panel_create_raw(
		parent_handle = parent_handle,
		uuid = core.uuid_create(allocator),
		name = strings.clone(name, allocator),
		rect = rect,
		spec = spec_clone(spec, allocator),
		allocator = allocator,
	)
}

@(private)
panel_create_raw :: proc(
	uuid: string,
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return Panel {
		uuid = uuid,
		parent_handle = parent_handle,
		children_handles = make([dynamic]PanelHandle, allocator),
		name = name,
		rect = rect,
		spec = spec,
	}
}

// @(private)
panel_flatten :: proc(
	scene: ^Scene,
	handle: PanelHandle,
	allocator: mem.Allocator = context.allocator,
) -> PanelFlat {
	panel := handle_map.get(scene.panels, handle)
	panel_flat := PanelFlat {
		panel.uuid,
		handle,
		panel.name,
		panel.rect,
		panel.spec,
		make([dynamic]PanelFlat, allocator),
	}

	for child_handle in panel.children_handles {
		child_flat := panel_flatten(scene, child_handle, allocator)
		append(&panel_flat.children, child_flat)
	}

	return panel_flat
}

panel_serialize :: proc(
	scene: ^Scene,
	handle: PanelHandle,
	allocator: mem.Allocator = context.allocator,
) -> string {
	panel_flat := panel_flatten(scene, handle, allocator)
	defer panel_flat_destroy(panel_flat)

	data, err := json.marshal(panel_flat, json.Marshal_Options{pretty = true}, allocator)
	if err != nil {
		log.warnf("Serialization of panel '%s' failed with error: %s", panel_flat.name, err)
	}

	return string(data)
}

@(private)
panel_flat_destroy :: proc(panel_flat: PanelFlat) {
	for child in panel_flat.children {
		panel_flat_destroy(child)
	}
	builtin.delete(panel_flat.children)
}

panel_unflatten :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	panel_flat: PanelFlat,
	allocator: mem.Allocator = context.allocator,
) -> PanelHandle {
	panel := panel_create_raw(
		strings.clone(panel_flat.uuid, allocator),
		parent_handle,
		strings.clone(panel_flat.name, allocator),
		panel_flat.rect,
		spec_clone(panel_flat.spec, allocator),
		allocator,
	)

	handle, err := handle_map.add(&scene.panels, panel)
	assert(err == mem.Allocator_Error.None)

	if parent_handle != EMPTY_HANDLE {
		parent := scene_get_panel(scene, parent_handle)
		assert(parent != nil)

		append(&parent.children_handles, handle)
	}

	for child in panel_flat.children {
		panel_unflatten(scene, handle, child, allocator)
	}

	return handle
}

// panel_deserialize :: proc(json_string: string, allocator := context.allocator) -> PanelFlat {
// 	json_bytes := transmute([]byte)json_string
// 	panel_flat: PanelFlat
// 	_ := json.unmarshal(json_bytes, &panel_flat)
// 	return panel_flat
// }

panel_hit_test :: proc(handle: PanelHandle, scene: ^Scene, position: [2]f32) -> PanelHandle {
	if handle == EMPTY_HANDLE {
		return EMPTY_HANDLE
	}

	panel := handle_map.get(scene.panels, handle)
	if panel == nil do return EMPTY_HANDLE

	if !core.contains(panel.rect, position) {
		return EMPTY_HANDLE
	}

	#reverse for child_handle in panel.children_handles {
		if hit := panel_hit_test(child_handle, scene, position); hit != EMPTY_HANDLE {
			return hit
		}
	}

	return EMPTY_HANDLE if panel.ignore_events else handle
}

panel_render :: proc(renderer: ^render.Renderer, scene: ^Scene, handle: PanelHandle) {
	panel := handle_map.get(scene.panels, handle)
	color := core.Color{255, 0, 0, 255}
	if panel.hovered do color = core.Color{0, 255, 0, 255}
	if panel.pressed do color = core.Color{0, 0, 255, 255}

	render.quad(renderer, panel.rect, color, 1, false)
	switch spec in panel.spec {
	case PanelSpec:
		break
	case TextSpec:
		render.text(renderer, spec.text, spec.font_handle, spec.font_size, panel.rect, spec.color)
	case ImageSpec:
		render.texture_by_atlas_name(
			renderer,
			spec.atlas_handle,
			spec.sprite_name,
			panel.rect,
			spec.color,
			spec.slice_offset,
		)
	}

	for child_handle in panel.children_handles {
		panel_render(renderer, scene, child_handle)
	}
}

panel_destroy :: proc(scene: ^Scene, panel: ^Panel, allocator: mem.Allocator = context.allocator) {
	if panel == nil do return

	for child_handle in panel.children_handles {
		panel_destroy(scene, scene_get_panel(scene, child_handle), allocator)
	}
	handle_map.remove(&scene.panels, panel.handle)

	spec_destroy(panel.spec, allocator)
	delete(panel.name, allocator)
	delete(panel.uuid, allocator)
	builtin.delete(panel.children_handles)
}
