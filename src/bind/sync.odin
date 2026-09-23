package omebind

import "core:log"
import "core:os"
import "ome:script"

import "ome:ui"

@(private)
view_sync_json :: proc(instance: ^Instance, view: ^View) {
	mtime, mtime_err := os.last_write_time_by_name(view.json_path)
	if mtime_err != nil || mtime == view.json_mtime do return
	view.json_mtime = mtime

	scene := ui.get_scene(instance.ui, view.scene_handle)
	if scene == nil do return

	desc, ok := read_view_json(instance, view.json_path)
	if !ok {
		log.warnf("bind: %s failed to load, keeping previous tree", view.json_path)
		return
	}

	if view.root_handle != ui.EMPTY_HANDLE {
		ui.scene_remove_panel(scene, view.root_handle)
	}
	view.root_handle = ui.panel_from_desc(scene, view.parent_handle, desc)
	log.infof("bind: loaded %s", view.json_path)
}

@(private)
view_sync_lua :: proc(instance: ^Instance, view: ^View) {
	if view.lua_path == "" do return

	mtime, mtime_err := os.last_write_time_by_name(view.lua_path)
	if mtime_err != nil || mtime == view.lua_mtime do return
	view.lua_mtime = mtime

	module, ok := script.load_module(instance.script, view.lua_path)
	if !ok {
		log.warnf("bind: %s failed to load, keeping previous module", view.lua_path)
		return
	}

	script.unref(instance.script, view.module)
	view.module = module
	log.infof("bind: loaded %s", view.lua_path)
}

@(private)
read_view_json :: proc(instance: ^Instance, path: string) -> (ui.PanelDesc, bool) {
	data, read_err := os.read_entire_file_from_path(path, context.temp_allocator)
	if read_err != nil {
		log.errorf("bind: can't read %s: %v", path, read_err)
		return {}, false
	}
	return ui.panel_desc_from_json(instance.assets, data, context.temp_allocator)
}
