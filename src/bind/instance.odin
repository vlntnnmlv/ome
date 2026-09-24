package omebind

import "core:log"
import "core:mem"
import "core:strings"
import "core:time"

import "ome:assets"
import "ome:script"
import "ome:ui"


Instance :: struct {
	ui:           ^ui.Instance,
	script:       ^script.Instance,
	assets:       ^assets.Instance,
	views:        [dynamic]View,
	allocator:    mem.Allocator,
	reload_timer: f32,
}

View :: struct {
	json_path:     string,
	lua_path:      string,
	scene_handle:  ui.SceneHandle,
	parent_handle: ui.PanelHandle,
	root_handle:   ui.PanelHandle,
	json_mtime:    time.Time,
	lua_mtime:     time.Time,
	module:        script.Ref,
	broken:        bool,
}

instance :: proc(
	ui_i: ^ui.Instance,
	script_i: ^script.Instance,
	assets_i: ^assets.Instance,
	allocator: mem.Allocator = context.allocator,
) -> ^Instance {
	instance := new(Instance, allocator)

	instance.allocator = allocator
	instance.ui = ui_i
	instance.script = script_i
	instance.assets = assets_i
	instance.views = make([dynamic]View, allocator)
	return instance
}

add_view :: proc(
	instance: ^Instance,
	lua_path: string,
	json_path: string = "",
	scene_handle: ui.SceneHandle = {},
	parent_handle: ui.PanelHandle = ui.EMPTY_HANDLE,
) -> bool {
	if json_path != "" && ui.get_scene(instance.ui, scene_handle) == nil do return false

	append(
		&instance.views,
		View {
			json_path = strings.clone(json_path, instance.allocator),
			lua_path = strings.clone(lua_path, instance.allocator),
			scene_handle = scene_handle,
			parent_handle = parent_handle,
			root_handle = ui.EMPTY_HANDLE,
			module = script.NO_REF,
		},
	)
	view := &instance.views[len(instance.views) - 1]

	view_sync_json(instance, view)
	if view.json_path != "" && view.root_handle == ui.EMPTY_HANDLE {
		log.errorf("bind: view %s has no panels", json_path)
		return false
	}

	view_sync_lua(instance, view)

	return true
}

update :: proc(instance: ^Instance, dt: f32) {
	dispatch_clicks(instance)

	instance.reload_timer += dt
	if instance.reload_timer >= 0.25 {
		instance.reload_timer = 0
		for &view in instance.views {
			view_sync_json(instance, &view)
			view_sync_lua(instance, &view)
		}
	}

	for &view in instance.views do call_hook(instance, &view, "update", f64(dt))

	refresh_bindings(instance)
}

draw :: proc(instance: ^Instance) {
	for &view in instance.views do call_hook(instance, &view, "draw")
}

@(private)
dispatch_clicks :: proc(instance: ^Instance) {
	for scene_handle in instance.ui.active_scenes_handles {
		scene := ui.get_scene(instance.ui, scene_handle)
		if scene == nil do continue

		for click in ui.scene_drain_clicks(scene) {
			if click.action == "" do continue

			view := view_owning(instance, scene, scene_handle, click.panel_handle)
			if view == nil || view.module == script.NO_REF {
				log.warnf(
					"bind: '%s' clicked, no model to handle '%s'",
					click.panel_name,
					click.action,
				)
				continue
			}
			cname := strings.clone_to_cstring(click.action, context.temp_allocator)
			if err, msg := script.call(instance.script, view.module, "actions", cname);
			   err != .None {
				log.errorf("bind: %s: action '%s': %s", view.lua_path, click.action, msg)
			}
		}
	}
}

@(private)
view_owning :: proc(
	instance: ^Instance,
	scene: ^ui.Scene,
	scene_handle: ui.SceneHandle,
	handle: ui.PanelHandle,
) -> ^View {
	current := handle
	for current != ui.EMPTY_HANDLE {
		for &view in instance.views {
			if view.scene_handle == scene_handle && view.root_handle == current do return &view
		}
		panel := ui.scene_get_panel(scene, current)
		if panel == nil do break
		current = panel.parent_handle
	}
	return nil
}

destroy :: proc(instance: ^Instance) {
	for &view in instance.views {
		script.unref(instance.script, view.module)
		delete(view.json_path, instance.allocator)
		delete(view.lua_path, instance.allocator)
	}

	delete(instance.views)
	free(instance, instance.allocator)
}
