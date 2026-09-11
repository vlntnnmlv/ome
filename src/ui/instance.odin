package omeui

import "base:runtime"
import "core:mem"

import "ome:core"
import "ome:core/handle_map"

Instance :: struct {
	scenes: handle_map.HandleMap(Scene, SceneHandle),
}

create :: proc(allocator: mem.Allocator = context.allocator) -> Instance {
	scenes, err := handle_map.make(Scene, SceneHandle, allocator)
	assert(err == runtime.Allocator_Error.None)
	return Instance{scenes = scenes}
}

add_scene :: proc(
	instance: ^Instance,
	rect: core.Rect,
	name: string,
	allocator: mem.Allocator = context.allocator,
) -> SceneHandle {
	handle, err := handle_map.add(&instance.scenes, scene_make(name, rect, allocator))
	assert(err == runtime.Allocator_Error.None)
	return handle
}

get_scene :: proc(instance: ^Instance, handle: SceneHandle) -> ^Scene {
	return handle_map.get(instance.scenes, handle)
}

delete :: proc(instance: ^Instance) {
	for &scene in instance.scenes.items {
		if scene.handle.idx == 0 do continue
		scene_delete(scene)
	}

	handle_map.delete(&instance.scenes)
}
