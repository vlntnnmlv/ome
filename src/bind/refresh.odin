package omebind

import "core:log"
import "ome:core"
import "ome:script"
import "ome:ui"
@(private)
refresh_bindings :: proc(instance: ^Instance) {
	for &view in instance.views {
		if view.module == script.NO_REF || view.broken do continue
		scene := ui.get_scene(instance.ui, view.scene_handle)
		if scene == nil do continue
		refresh_panel(instance, scene, &view, view.root_handle)
	}
}

@(private)
refresh_panel :: proc(instance: ^Instance, scene: ^ui.Scene, view: ^View, handle: ui.PanelHandle) {
	panel := ui.scene_get_panel(scene, handle)
	if panel == nil do return

	for binding in panel.bindings {
		err: script.Error
		msg: string
		switch binding.target {
		case .Text:
			text: string
			text, err, msg = script.get_string(instance.script, view.module, binding.path)
			if err == .None do ui.panel_set_text(scene, handle, text)
		case .Color:
			c: [4]f32
			err, msg = script.get_numbers(instance.script, view.module, binding.path, c[:])
			if err == .None do ui.panel_set_color(scene, handle, core.Color{u8(c[0]), u8(c[1]), u8(c[2]), u8(c[3])})
		}
		if err != .None && err != .Missing {
			view.broken = true
			log.errorf("bind: %s: binding '%s': %s", view.lua_path, binding.path, msg)
			log.warnf("bind: %s paused until the file is saved again", view.lua_path)
			return
		}
	}

	for child in panel.children_handles do refresh_panel(instance, scene, view, child)
}
