package omeui

import "core:mem"

import "ome:core"
import "ome:handle_map"
import "ome:platform"
import "ome:render"

Stage :: struct {
	scenes:               handle_map.Map(Scene, SceneHandle),
	active_scene_handles: [dynamic]SceneHandle,
}

stage_create :: proc(allocator: mem.Allocator = context.allocator) -> ^Stage {
	stage := new(Stage)

	scenes, err := handle_map.make(Scene, SceneHandle, allocator)
	ensure(err == nil)
	stage.scenes = scenes
	stage.active_scene_handles = make([dynamic]SceneHandle, allocator)

	return stage
}

stage_add_scene :: proc(
	stage: ^Stage,
	name: string,
	rect: core.Rect,
	allocator: mem.Allocator = context.allocator,
) -> SceneHandle {
	handle, err := handle_map.add(&stage.scenes, scene_create(name, rect, allocator))
	ensure(err == nil)

	return handle
}

stage_get_scene :: proc(stage: ^Stage, handle: SceneHandle) -> ^Scene {
	return handle_map.get(stage.scenes, handle)
}

stage_handle_event :: proc(user_data: rawptr, event: platform.Event) -> bool {
	stage := cast(^Stage)user_data
	blocked := false

	#reverse for scene_handle in stage.active_scene_handles {
		scene := stage_get_scene(stage, scene_handle)
		if scene == nil {
			continue
		}

		if blocked {
			if platform.event_is_mouse(event) {
				scene_clear_hover(scene)
			}
			continue
		}

		if scene_handle_event(scene, event) || (scene.modal && platform.event_is_mouse(event)) {
			blocked = true
		}
	}

	return blocked
}

@(private)
stage_active_scene_index :: proc(stage: ^Stage, handle: SceneHandle) -> int {
	for scene_handle, i in stage.active_scene_handles {
		if scene_handle == handle {
			return i
		}
	}

	return -1
}

stage_show_scene :: proc(stage: ^Stage, handle: SceneHandle) {
	assert(stage_get_scene(stage, handle) != nil)

	if i := stage_active_scene_index(stage, handle); i >= 0 {
		ordered_remove(&stage.active_scene_handles, i)
	}
	append(&stage.active_scene_handles, handle)
}

stage_hide_scene :: proc(stage: ^Stage, handle: SceneHandle) {
	i := stage_active_scene_index(stage, handle)
	if i < 0 {
		return
	}
	ordered_remove(&stage.active_scene_handles, i)
	if scene := stage_get_scene(stage, handle); scene != nil {
		scene_clear_input(scene)
	}
}

stage_render :: proc(stage: ^Stage, renderer: ^render.Renderer) {
	for handle in stage.active_scene_handles {
		if scene := stage_get_scene(stage, handle); scene != nil {
			scene_render(scene, renderer)
		}
	}
}

stage_destroy :: proc(stage: ^Stage) {
	scenes_iter := handle_map.make_iter(&stage.scenes)
	for scene in handle_map.iter(&scenes_iter) {
		scene_destroy(scene)
	}

	delete(stage.active_scene_handles)
	handle_map.delete(&stage.scenes)

	free(stage)
}
