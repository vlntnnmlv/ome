package omebind

import "core:log"
import "core:os"

import "ome:script"
import "ome:ui"

@(private)
binder_view_sync_json :: proc(binder: ^Binder, view: ^View) {
	if view.json_path == "" {
		return
	}

	mtime, mtime_err := os.last_write_time_by_name(view.json_path)
	if mtime_err != nil || mtime == view.json_mtime {
		return
	}
	view.json_mtime = mtime

	scene := ui.stage_get_scene(binder.stage, view.scene_handle)
	if scene == nil {
		return
	}

	desc, ok := binder_read_view_json(binder, view.json_path)
	if !ok {
		log.warnf("bind/sync: %s failed to load, keeping previous tree", view.json_path)
		return
	}

	if view.root_handle != ui.NO_PANEL {
		ui.scene_remove_panel(scene, view.root_handle)
	}
	view.root_handle = ui.panel_from_description(scene, view.parent_handle, desc)
	log.infof("bind/sync: loaded %s", view.json_path)
}

@(private)
binder_view_sync_lua :: proc(binder: ^Binder, view: ^View) {
	if view.lua_path == "" {
		return
	}

	mtime, mtime_err := os.last_write_time_by_name(view.lua_path)
	if mtime_err != nil || mtime == view.lua_mtime {
		return
	}
	view.lua_mtime = mtime

	module, ok := script.vm_load_module(binder.vm, view.lua_path)
	if !ok {
		log.warnf("bind/sync: %s failed to load, keeping previous module", view.lua_path)
		return
	}

	script.vm_unref(binder.vm, view.module_ref)
	view.module_ref = module
	view.broken = false
	log.infof("bind/sync: loaded %s", view.lua_path)
}

@(private)
binder_call_hook :: proc(binder: ^Binder, view: ^View, name: cstring, args: ..f64) {
	if view.module_ref == script.NO_REF || view.broken {
		return
	}

	err, msg := script.vm_call(binder.vm, view.module_ref, nil, name, ..args)
	if err == .None || err == .Missing {
		return
	}

	view.broken = true
	log.errorf("bind/sync: %s: %s: %s", view.lua_path, name, msg)
	log.warnf("bind/sync: %s hooks paused until the file is saved again", view.lua_path)
}

@(private)
binder_read_view_json :: proc(binder: ^Binder, path: string) -> (ui.PanelDescription, bool) {
	data, read_err := os.read_entire_file_from_path(path, context.temp_allocator)
	if read_err != nil {
		log.errorf("bind/sync: can't read %s: %v", path, read_err)
		return {}, false
	}
	return ui.panel_description_from_json(binder.library, data, context.temp_allocator)
}
