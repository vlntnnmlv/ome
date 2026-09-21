package omeui

import "base:builtin"
import "core:encoding/json"
import "core:io"
import "core:log"
import "core:mem"

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
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return Panel {
		uuid = core.uuid_create(allocator),
		parent_handle = parent_handle,
		children_handles = make([dynamic]PanelHandle, allocator),
		name = name,
		rect = rect,
		spec = spec,
	}
}

@(private)
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
		child_flat := panel_flatten(scene, child_handle)
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
	defer delete(panel_flat.children)

	data, err := json.marshal(panel_flat, json.Marshal_Options{pretty = true}, allocator)
	if err != json.Marshal_Data_Error.None || err != io.Error.None {
		log.warn("Serialization of panel '%s' failed with error: %s", panel_flat.name, err)
	}

	return string(data)
}

panel_unflatten :: proc(scene: ^Scene, panel_flat: PanelFlat) {

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

	if !core.contains(panel.rect, position) {
		return EMPTY_HANDLE
	}

	n := len(panel.children_handles)
	for i := n - 1; i >= 0; i -= 1 {
		child_handle := panel.children_handles[i]
		if hit := panel_hit_test(child_handle, scene, position); hit != EMPTY_HANDLE {
			return hit
		}
	}

	return handle
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
	for child_handle in panel.children_handles {
		panel_destroy(scene, handle_map.get(scene.panels, child_handle), allocator)
	}

	delete(panel.uuid, allocator)
	builtin.delete(panel.children_handles)
}
