package omeui

import "core:mem"

import "ome:core"
import "ome:core/handle_map"


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

// panel_process_event :: proc(
// 	ui_panel_handle: PanelHandle,
// 	ui_manager: ^Manager,
// 	e: SDL.Event,
// ) -> bool {
// 	if e.type != .MOUSE_MOTION do return false

// 	panel := &ui_manager.panels[ui_panel_handle]
// 	child_catched := false
// 	for child in panel.children {
// 		child_catched = panel_process_event(child, ui_manager, e)
// 	}

// 	panel.hovered = !child_catched && core.contains(panel.rect, {e.motion.x, e.motion.y})
// 	return panel.hovered
// }

panel_render :: proc(resources: ^core.Resources, scene: ^Scene, handle: PanelHandle) {
	panel := handle_map.get(scene.panels, handle)
	color := core.Color{255, 0, 0, 255}
	if panel.hovered do color = core.Color{0, 255, 0, 255}

	core.render_quad(resources.gpu, panel.rect, color, 1, false)
	switch spec in panel.spec {
	case PanelSpec:
		break
	case TextSpec:
		core.render_text(
			resources,
			spec.text,
			spec.font_handle,
			spec.font_size,
			panel.rect,
			spec.color,
		)
	case ImageSpec:
		core.render_texture_by_atlas_name(
			resources,
			spec.atlas_handle,
			spec.sprite_name,
			panel.rect,
			spec.color,
			spec.slice_offset,
		)
	}

	for child_handle in panel.children_handles {
		panel_render(resources, scene, child_handle)
	}
}
