package omebind

import "core:hash"
import "core:log"
import "core:os"
import "core:time"

import "ome:script"
import "ome:ui"

@(private)
binder_view_sync_json :: proc(binder: ^Binder, view: ^View) {
	if view.json_path == "" {
		return
	}

	data, new_hash, changed := file_read_if_changed(
		view.json_path,
		&view.json_mtime,
		view.json_hash,
		false,
	)

	if !changed {
		return
	}

	scene := ui.stage_get_scene(binder.stage, view.scene_handle)
	if scene == nil {
		return
	}

	desc, ok := ui.panel_description_from_json(binder.library, data, context.temp_allocator)
	if !ok {
		log.warnf("bind/sync: %s failed to load, keeping previous tree", view.json_path)
		return
	}
	view.json_hash = new_hash

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

	data, new_hash, changed := file_read_if_changed(
		view.lua_path,
		&view.lua_mtime,
		view.lua_hash,
		view.broken,
	)
	if !changed {
		return
	}

	module, ok := script.vm_load_module(binder.vm, data, view.lua_path)
	if !ok {
		log.warnf("bind/sync: %s failed to load, keeping previous module", view.lua_path)
		return
	}

	script.vm_unref(binder.vm, view.module_ref)
	view.module_ref = module
	view.lua_hash = new_hash
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
file_read_if_changed :: proc(
	path: string,
	mtime: ^time.Time,
	last_hash: u64,
	force: bool,
) -> (
	data: []byte,
	new_hash: u64,
	changed: bool,
) {
	new_mtime, mtime_err := os.last_write_time_by_name(path)
	if mtime_err != nil || new_mtime == mtime^ {
		return
	}
	mtime^ = new_mtime

	file_data, read_err := os.read_entire_file_from_path(path, context.temp_allocator)
	if read_err != nil {
		log.errorf("bind/sync: can't read %s: %v", path, read_err)
		return
	}

	data = file_data
	new_hash = hash.fnv64a(data)
	changed = force || new_hash != last_hash
	return
}
