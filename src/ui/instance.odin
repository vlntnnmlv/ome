package omeui

import "base:runtime"
import "core:mem"

import "ome:core"
import "ome:handle_map"
import "ome:platform"
import "ome:render"

Instance :: struct {
	scenes:                handle_map.Map(Scene, SceneHandle),
	active_scenes_handles: [dynamic]SceneHandle,
}

instance :: proc(allocator: mem.Allocator = context.allocator) -> Instance {
	scenes, err := handle_map.make(Scene, SceneHandle, allocator)
	assert(err == runtime.Allocator_Error.None)
	return Instance{scenes = scenes, active_scenes_handles = make([dynamic]SceneHandle, allocator)}
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
	blocked := false

	#reverse for scene_handle in instance.active_scenes_handles {
		scene := get_scene(instance, scene_handle)
		if scene == nil do continue

		if blocked {
			if platform.is_mouse_event(event) do scene_clear_hover(scene)
			continue
		}

		if scene_handle_event(scene, event) || (scene.is_modal && platform.is_mouse_event(event)) {
			blocked = true
		}
	}

	return blocked
}

@(private)
active_index :: proc(instance: ^Instance, handle: SceneHandle) -> int {
	for scene_handle, i in instance.active_scenes_handles {
		if scene_handle == handle do return i
	}

	return -1
}

show_scene :: proc(instance: ^Instance, handle: SceneHandle) {
	ensure(get_scene(instance, handle) != nil)

	if i := active_index(instance, handle); i >= 0 {
		ordered_remove(&instance.active_scenes_handles, i)
	}
	append(&instance.active_scenes_handles, handle)
}

hide_scene :: proc(instance: ^Instance, handle: SceneHandle) {
	i := active_index(instance, handle)
	if i < 0 do return
	ordered_remove(&instance.active_scenes_handles, i)
	if scene := get_scene(instance, handle); scene != nil {
		scene_clear_input(scene)
	}
}

render :: proc(renderer: ^render.Renderer, instance: ^Instance) {
	for handle in instance.active_scenes_handles {
		if scene := get_scene(instance, handle); scene != nil {
			scene_render(renderer, scene)
		}
	}
}

destroy :: proc(instance: ^Instance) {
	for &scene in instance.scenes.items {
		if scene.handle.idx == 0 do continue
		scene_destroy(scene)
	}

	delete(instance.active_scenes_handles)
	handle_map.delete(&instance.scenes)
}
