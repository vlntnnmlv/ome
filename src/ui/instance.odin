package omeui

import "base:runtime"
import "core:mem"
import "ome:platform"

import "ome:core"
import "ome:handle_map"

Instance :: struct {
	scenes: handle_map.HandleMap(Scene, SceneHandle),
}

instance :: proc(allocator: mem.Allocator = context.allocator) -> Instance {
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
	handle, err := handle_map.add(&instance.scenes, scene_create(name, rect, allocator))
	assert(err == runtime.Allocator_Error.None)
	return handle
}

get_scene :: proc(instance: ^Instance, handle: SceneHandle) -> ^Scene {
	return handle_map.get(instance.scenes, handle)
}

handle_event :: proc(user_data: rawptr, event: platform.Event) -> bool {
	instance := cast(^Instance)user_data
	// TODO: User iter
	for &scene in instance.scenes.items {
		if scene.handle.idx == 0 do continue
		if scene_handle_event(scene, event) do return true
	}

	return false
}

destroy :: proc(instance: ^Instance) {
	for &scene in instance.scenes.items {
		if scene.handle.idx == 0 do continue
		scene_destroy(scene)
	}

	handle_map.delete(&instance.scenes)
}
