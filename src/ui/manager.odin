package omeui

import "base:runtime"
import "core:mem"

import "ome:core"
import "ome:core/handle_map"

UI :: struct {
	scenes: handle_map.HandleMap(Scene, SceneHandle),
}

create :: proc(allocator: mem.Allocator = context.allocator) -> UI {
	scenes, err := handle_map.make(Scene, SceneHandle, allocator)
	assert(err == runtime.Allocator_Error.None)
	return UI{scenes = scenes}
}

add_scene :: proc(
	ui: ^UI,
	rect: core.Rect,
	name: string,
	allocator: mem.Allocator = context.allocator,
) -> SceneHandle {
	handle, err := handle_map.add(&ui.scenes, scene_make(name, rect, allocator))
	assert(err == runtime.Allocator_Error.None)
	return handle
}

delete :: proc(ui: ^UI) {
	for &scene in ui.scenes.items {
		if scene.handle.idx == 0 do continue
		scene_delete(scene)
	}

	handle_map.delete(&ui.scenes)
}
