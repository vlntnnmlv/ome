package omebind

import "core:log"
import "core:mem"
import "core:strings"
import "core:time"

import "ome:assets"
import "ome:script"
import "ome:ui"


Binder :: struct {
	stage:        ^ui.Stage,
	vm:           ^script.VM,
	library:      ^assets.Library,
	views:        [dynamic]View,
	allocator:    mem.Allocator,
	reload_timer: f32,
}

View :: struct {
	json_path:     string,
	lua_path:      string,
	json_hash:     u64,
	lua_hash:      u64,
	scene_handle:  ui.SceneHandle,
	parent_handle: ui.PanelHandle,
	root_handle:   ui.PanelHandle,
	json_mtime:    time.Time,
	lua_mtime:     time.Time,
	module_ref:    script.Ref,
	broken:        bool,
}

binder_create :: proc(
	stage: ^ui.Stage,
	vm: ^script.VM,
	library: ^assets.Library,
	allocator: mem.Allocator = context.allocator,
) -> ^Binder {
	binder := new(Binder, allocator)

	binder.allocator = allocator
	binder.stage = stage
	binder.vm = vm
	binder.library = library
	binder.views = make([dynamic]View, allocator)
	return binder
}

NO_LUA: string : ""
NO_JSON: string : ""

binder_add_view :: proc(
	binder: ^Binder,
	lua_path: string,
	json_path: string = "",
	scene_handle: ui.SceneHandle = {},
	parent_handle: ui.PanelHandle = ui.NO_PANEL,
) -> bool {
	if json_path != "" && ui.stage_get_scene(binder.stage, scene_handle) == nil {
		return false
	}

	append(
		&binder.views,
		View {
			json_path = strings.clone(json_path, binder.allocator),
			lua_path = strings.clone(lua_path, binder.allocator),
			scene_handle = scene_handle,
			parent_handle = parent_handle,
			root_handle = ui.NO_PANEL,
			module_ref = script.NO_REF,
		},
	)
	view := &binder.views[len(binder.views) - 1]

	binder_view_sync_json(binder, view)
	if view.json_path != "" && view.root_handle == ui.NO_PANEL {
		log.errorf("bind: view %s has no panels", json_path)
		return false
	}

	binder_view_sync_lua(binder, view)

	return true
}

binder_update :: proc(binder: ^Binder, dt: f32) {
	binder_dispatch_clicks(binder)

	binder.reload_timer += dt
	if binder.reload_timer >= 0.25 {
		binder.reload_timer = 0
		for &view in binder.views {
			binder_view_sync_json(binder, &view)
			binder_view_sync_lua(binder, &view)
		}
	}

	for &view in binder.views {
		binder_call_hook(binder, &view, "update", f64(dt))
	}

	binder_refresh_bindings(binder)
}

binder_draw :: proc(binder: ^Binder) {
	for &view in binder.views {
		binder_call_hook(binder, &view, "draw")
	}
}

@(private)
binder_dispatch_clicks :: proc(binder: ^Binder) {
	for scene_handle in binder.stage.active_scene_handles {
		scene := ui.stage_get_scene(binder.stage, scene_handle)
		if scene == nil {
			continue
		}

		for click in ui.scene_drain_clicks(scene) {
			if click.action == "" {
				continue
			}

			view := binder_view_owning(binder, scene, scene_handle, click.panel_handle)
			if view == nil || view.module_ref == script.NO_REF {
				log.warnf(
					"bind: '%s' clicked, no model to handle '%s'",
					click.panel_name,
					click.action,
				)
				continue
			}
			cname := strings.clone_to_cstring(click.action, context.temp_allocator)
			if err, msg := script.vm_call(binder.vm, view.module_ref, "actions", cname);
			   err != .None {
				log.errorf("bind: %s: action '%s': %s", view.lua_path, click.action, msg)
			}
		}
	}
}

@(private)
binder_view_owning :: proc(
	binder: ^Binder,
	scene: ^ui.Scene,
	scene_handle: ui.SceneHandle,
	panel_handle: ui.PanelHandle,
) -> ^View {
	current_handle := panel_handle
	for current_handle != ui.NO_PANEL {
		for &view in binder.views {
			if view.scene_handle == scene_handle && view.root_handle == current_handle {
				return &view
			}
		}
		panel := ui.scene_get_panel(scene, current_handle)
		if panel == nil {
			break
		}
		current_handle = panel.parent_handle
	}
	return nil
}

binder_destroy :: proc(binder: ^Binder) {
	for &view in binder.views {
		script.vm_unref(binder.vm, view.module_ref)
		delete(view.json_path, binder.allocator)
		delete(view.lua_path, binder.allocator)
	}

	delete(binder.views)
	free(binder, binder.allocator)
}
