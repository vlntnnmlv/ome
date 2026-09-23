package omebind

import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

import "ome:assets"
import "ome:script"
import "ome:ui"


Instance :: struct {
	ui_i:         ^ui.Instance,
	script_i:     ^script.Instance,
	assets_i:     ^assets.Instance,
	views:        [dynamic]View,
	allocator:    mem.Allocator,
	reload_timer: f32,
}

View :: struct {
	path:          string,
	scene_handle:  ui.SceneHandle,
	parent_handle: ui.PanelHandle,
	root_handle:   ui.PanelHandle,
	mtime:         time.Time,
}

instance :: proc(
	ui_i: ^ui.Instance,
	script_i: ^script.Instance,
	assets_i: ^assets.Instance,
	allocator: mem.Allocator = context.allocator,
) -> ^Instance {
	instance := new(Instance, allocator)

	instance.allocator = allocator
	instance.ui_i = ui_i
	instance.script_i = script_i
	instance.assets_i = assets_i
	instance.views = make([dynamic]View, allocator)
	return instance
}

add_view :: proc(
	instance: ^Instance,
	scene_handle: ui.SceneHandle,
	parent_handle: ui.PanelHandle,
	path: string,
) -> bool {
	scene := ui.get_scene(instance.ui_i, scene_handle)
	if scene == nil do return false

	flat, ok := panel_flat_from_lua_file(
		instance.script_i,
		instance.assets_i,
		path,
		context.temp_allocator,
	)
	root := ui.EMPTY_HANDLE
	if ok do root = ui.panel_unflatten(scene, parent_handle, flat, instance.allocator)
	mtime, _ := os.last_write_time_by_name(path)

	append(
		&instance.views,
		View {
			path = strings.clone(path, instance.allocator),
			scene_handle = scene_handle,
			parent_handle = parent_handle,
			root_handle = root,
			mtime = mtime,
		},
	)

	return ok
}

update :: proc(instance: ^Instance, dt: f32) {
	instance.reload_timer += dt
	if instance.reload_timer < 0.25 do return

	for &view in instance.views {
		mtime, err := os.last_write_time_by_name(view.path)
		if err != nil || mtime == view.mtime do continue

		view.mtime = mtime

		scene := ui.get_scene(instance.ui_i, view.scene_handle)
		if scene == nil do continue

		flat, ok := panel_flat_from_lua_file(
			instance.script_i,
			instance.assets_i,
			view.path,
			context.temp_allocator,
		)
		if !ok {
			log.warnf("ui/lua: %s failed to reload, keeping previous tree", view.path)
			continue
		}

		if view.root_handle != ui.EMPTY_HANDLE {
			ui.scene_remove_panel(scene, view.root_handle, instance.allocator)
		}
		view.root_handle = ui.panel_unflatten(scene, view.parent_handle, flat, instance.allocator)
		log.infof("ui/lua: reloaded %s", view.path)
	}
}

destroy :: proc(instance: ^Instance) {
	for &view in instance.views {
		delete(view.path)
	}

	delete(instance.views)
	free(instance, instance.allocator)
}
