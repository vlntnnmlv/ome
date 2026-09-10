package omeui

import "base:runtime"
import "core:mem"

import "ome:core"
import "ome:core/handle_map"

Manager :: struct {
	scenes: handle_map.HandleMap(Scene, SceneHandle),
}

manager_create :: proc(allocator: mem.Allocator = context.allocator) -> Manager {
	scenes, err := handle_map.make(Scene, SceneHandle, allocator)
	assert(err == runtime.Allocator_Error.None)
	return Manager{scenes = scenes}
}

manager_add_scene :: proc(
	manager: ^Manager,
	rect: core.Rect,
	name: string,
	allocator: mem.Allocator = context.allocator,
) -> SceneHandle {
	handle, err := handle_map.add(&manager.scenes, scene_make(name, rect, allocator))
	assert(err == runtime.Allocator_Error.None)
	return handle
}

manager_delete :: proc(manager: ^Manager) {
	for &scene in manager.scenes.items {
		if scene.handle.idx == 0 do continue
		scene_delete(scene)
	}

	handle_map.delete(&manager.scenes)
}
