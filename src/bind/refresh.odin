package omebind

import "ome:core"
import "ome:script"
import "ome:ui"
@(private)
refresh_bindings :: proc(instance: ^Instance) {
	for &view in instance.views {
		if view.module == script.NO_REF do continue
		scene := ui.get_scene(instance.ui, view.scene_handle)
		if scene == nil do continue
		refresh_panel(instance, scene, view.module, view.root_handle)
	}
}

@(private)
refresh_panel :: proc(
	instance: ^Instance,
	scene: ^ui.Scene,
	module: script.Ref,
	handle: ui.PanelHandle,
) {
	panel := ui.scene_get_panel(scene, handle)
	if panel == nil do return

	for binding in panel.bindings {
		switch binding.target {
		case .Text:
			if text, ok := script.get_string(instance.script, module, "model", binding.path); ok {
				ui.panel_set_text(scene, handle, text)
			}
		case .Color:
			c: [4]f32
			if script.get_numbers(instance.script, module, "model", binding.path, c[:]) {
				ui.panel_set_color(
					scene,
					handle,
					core.Color{u8(c[0]), u8(c[1]), u8(c[2]), u8(c[3])},
				)
			}
		}
	}

	for child in panel.children_handles do refresh_panel(instance, scene, module, child)
}
