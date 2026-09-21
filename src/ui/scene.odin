package omeui

import "base:runtime"
import "core:mem"
import "ome:platform"

import "ome:core"
import "ome:handle_map"
import "ome:render"

SceneHandle :: distinct handle_map.Handle

Scene :: struct {
	uuid:           string,
	handle:         SceneHandle,
	root_handle:    PanelHandle,
	hovered_handle: PanelHandle,
	pressed_handle: PanelHandle,
	clicks:         [dynamic]Click,
	panels:         handle_map.HandleMap(Panel, PanelHandle),
	name:           string,
}

Click :: struct {
	panel_handle: PanelHandle,
	button:       platform.MouseButton,
	count:        u8,
}

scene_create :: proc(
	name: string,
	rect: core.Rect,
	allocator: mem.Allocator = context.allocator,
) -> Scene {
	panels, err := handle_map.make(Panel, PanelHandle, allocator)
	assert(err == runtime.Allocator_Error.None)

	scene: Scene = {
		uuid   = core.uuid_create(allocator),
		panels = panels,
		clicks = make([dynamic]Click),
	}

	root_panel := panel_create(EMPTY_HANDLE, "root", rect, PanelSpec{}, allocator)

	root_handle, err_2 := handle_map.add(&scene.panels, root_panel)
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
	panel := panel_create(parent_handle, name, rect, spec, allocator)
	panel_handle, err := handle_map.add(&scene.panels, panel)
	assert(err == runtime.Allocator_Error.None)

	if parent_handle == EMPTY_HANDLE do return

	parent := handle_map.get(scene.panels, parent_handle)
	append(&parent.children_handles, panel_handle)
}

scene_get_panel :: proc(scene: ^Scene, handle: PanelHandle) -> ^Panel {
	return handle_map.get(scene.panels, handle)
}

scene_handle_event :: proc(scene: ^Scene, event: platform.Event) -> bool {
	#partial switch e in event {
	case platform.ResizeEvent:
		root := scene_get_panel(scene, scene.root_handle)
		root.rect = core.Rect{0, 0, f32(e.info.logical_width), f32(e.info.logical_height)}
		return false
	case platform.MouseMoveEvent:
		hit := panel_hit_test(scene.root_handle, scene, e.position)
		if hit != scene.hovered_handle {
			if scene.hovered_handle != EMPTY_HANDLE {
				scene_get_panel(scene, scene.hovered_handle).hovered = false
			}
			if hit != EMPTY_HANDLE {
				scene_get_panel(scene, hit).hovered = true
			}

			scene.hovered_handle = hit
		}
		return hit != EMPTY_HANDLE
	case platform.MouseButtonEvent:
		hit := panel_hit_test(scene.root_handle, scene, e.position)
		if e.down {
			if hit != EMPTY_HANDLE {
				scene_get_panel(scene, hit).pressed = true
				scene.pressed_handle = hit
			}
			return hit != EMPTY_HANDLE
		}

		was := scene.pressed_handle
		if was != EMPTY_HANDLE {
			scene_get_panel(scene, was).pressed = false
			scene.pressed_handle = EMPTY_HANDLE
		}

		if hit != EMPTY_HANDLE && hit == was {
			append(&scene.clicks, Click{panel_handle = hit, button = e.button, count = e.clicks})
		}
		return was != EMPTY_HANDLE
	}

	return false
}

scene_drain_clicks :: proc(scene: ^Scene, allocator := context.temp_allocator) -> []Click {
	out := make([]Click, len(scene.clicks), allocator)

	copy(out, scene.clicks[:])
	clear(&scene.clicks)
	return out
}

scene_render :: proc(renderer: ^render.Renderer, scene: ^Scene) {
	panel_render(renderer, scene, scene.root_handle)
}

scene_destroy :: proc(scene: ^Scene, allocator: mem.Allocator = context.allocator) {
	panel_destroy(scene, handle_map.get(scene.panels, scene.root_handle), allocator)

	delete(scene.clicks)
	handle_map.delete(&scene.panels)
	delete(scene.uuid, allocator)
}
