package omebind

import "core:log"

import "ome:core"
import "ome:script"
import "ome:ui"

@(private)
binder_refresh_bindings :: proc(binder: ^Binder) {
	for &view in binder.views {
		if view.module_ref == script.NO_REF || view.broken {
			continue
		}

		scene := ui.stage_get_scene(binder.stage, view.scene_handle)
		if scene == nil {
			continue
		}
		binder_refresh_panel(binder, scene, &view, view.root_handle)
	}
}

@(private)
binder_refresh_panel :: proc(
	binder: ^Binder,
	scene: ^ui.Scene,
	view: ^View,
	handle: ui.PanelHandle,
) {
	panel := ui.scene_get_panel(scene, handle)
	if panel == nil {
		return
	}

	for binding in panel.bindings {
		err: script.Error
		msg: string
		switch binding.target {
		case .Text:
			text: string
			text, err, msg = script.vm_get_string(binder.vm, view.module_ref, binding.path)
			if err == .None {
				ui.panel_set_text(scene, handle, text)
			}
		case .Color:
			c: [4]f32
			err, msg = script.vm_get_numbers(binder.vm, view.module_ref, binding.path, c[:])
			if err == .None {
				ui.panel_set_color(
					scene,
					handle,
					core.Color{u8(c[0]), u8(c[1]), u8(c[2]), u8(c[3])},
				)
			}
		}
		if err != .None && err != .Missing {
			view.broken = true
			log.errorf("bind/refresh: %s: binding '%s': %s", view.lua_path, binding.path, msg)
			log.warnf("bind/refresh: %s paused until the file is saved again", view.lua_path)
			return
		}
	}

	for child in panel.child_handles {
		binder_refresh_panel(binder, scene, view, child)
	}
}
