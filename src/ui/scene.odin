package omeui

import "../core"
import "base:runtime"
import "core:fmt"

import "core:mem"

SceneHandle :: distinct core.Handle

Scene :: struct {
	uuid:        core.UUID,
	handle:      SceneHandle,
	root_handle: PanelHandle,
	panels:      core.HandleMap(Panel, PanelHandle),
	name:        string,
}

scene_make :: proc(
	name: string,
	rect: core.Rect,
	allocator: mem.Allocator = context.allocator,
) -> Scene {
	panels, err := core.handle_map_make(Panel, PanelHandle, allocator)
	assert(err == runtime.Allocator_Error.None)

	scene: Scene = {
		uuid   = core.uuid_make(allocator),
		panels = panels,
	}

	root_panel := panel_make(EMPTY_HANDLE, "root", rect, PanelSpec{}, allocator)

	root_handle, err_2 := core.handle_map_add(&scene.panels, root_panel)
	assert(err_2 == runtime.Allocator_Error.None)

	scene.root_handle = root_handle
	scene.name = name

	return scene
}

scene_serialize :: proc(scene: ^Scene) {

}

scene_add_panel :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator: mem.Allocator = context.allocator,
) {
	panel := panel_make(parent_handle, name, rect, spec, allocator)
	panel_handle, err := core.handle_map_add(&scene.panels, panel)
	assert(err == runtime.Allocator_Error.None)

	if parent_handle == EMPTY_HANDLE do return

	parent := core.handle_map_get(scene.panels, parent_handle)
	append(&parent.children_handles, panel_handle)
}

scene_render :: proc(renderer: ^core.Renderer, scene: ^Scene) {
	panel_render(renderer, scene, scene.root_handle)
}

scene_delete :: proc(scene: ^Scene, allocator: mem.Allocator = context.allocator) {
	panel_delete(scene, core.handle_map_get(scene.panels, scene.root_handle), allocator)

	core.uuid_delete(&scene.uuid, allocator)
	core.handle_map_delete(&scene.panels)
}
