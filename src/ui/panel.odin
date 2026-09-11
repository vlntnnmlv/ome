package omeui

import "core:mem"

import "ome:core"
import "ome:core/handle_map"
import "ome:core/render"
import "ome:core/resources"

PanelHandle :: distinct handle_map.Handle

EMPTY_HANDLE :: PanelHandle{}

Panel :: struct {
	uuid:             core.UUID,
	handle:           PanelHandle,
	parent_handle:    PanelHandle,
	children_handles: [dynamic]PanelHandle,
	name:             string,
	rect:             core.Rect,
	spec:             Spec,
	hovered:          bool,
}

panel_make :: proc(
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return Panel {
		uuid = core.uuid_make(allocator),
		parent_handle = parent_handle,
		children_handles = make([dynamic]PanelHandle, allocator),
		name = name,
		rect = rect,
		spec = spec,
	}
}

panel_delete :: proc(scene: ^Scene, panel: ^Panel, allocator: mem.Allocator = context.allocator) {
	for child_handle in panel.children_handles {
		panel_delete(scene, handle_map.get(scene.panels, child_handle), allocator)
	}

	core.uuid_delete(&panel.uuid, allocator)
	delete(panel.children_handles)
}

panel_render :: proc(rsrcs: ^resources.Resources, scene: ^Scene, handle: PanelHandle) {
	panel := handle_map.get(scene.panels, handle)
	color := core.Color{255, 0, 0, 255}
	if panel.hovered do color = core.Color{0, 255, 0, 255}

	render.quad(rsrcs.renderer, panel.rect, color, 1, false)
	switch spec in panel.spec {
	case PanelSpec:
		break
	case TextSpec:
		render.text(rsrcs, spec.text, spec.font_handle, spec.font_size, panel.rect, spec.color)
	case ImageSpec:
		render.texture_by_atlas_name(
			rsrcs,
			spec.atlas_handle,
			spec.sprite_name,
			panel.rect,
			spec.color,
			spec.slice_offset,
		)
	}

	for child_handle in panel.children_handles {
		panel_render(rsrcs, scene, child_handle)
	}
}
