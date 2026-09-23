package omeui

import "base:runtime"
import "core:mem"
import "core:strings"
import "ome:platform"

import "ome:core"
import "ome:handle_map"
import "ome:render"

SceneHandle :: distinct handle_map.Handle

Scene :: struct {
	allocator:           mem.Allocator,
	uuid:                string,
	handle:              SceneHandle,
	root_handle:         PanelHandle,
	hovered_handle:      PanelHandle,
	pressed_handle:      PanelHandle,
	clicks:              [dynamic]Click,
	panels:              handle_map.Map(Panel, PanelHandle),
	name:                string,
	is_modal:            bool,
	is_following_window: bool,
	is_debug:            bool,
}

Click :: struct {
	panel_handle: PanelHandle,
	panel_name:   string,
	button:       platform.MouseButton,
	count:        u8,
	action:       string,
}

scene_create :: proc(
	name: string,
	rect: core.Rect,
	allocator: mem.Allocator = context.allocator,
) -> Scene {
	panels, err := handle_map.make(Panel, PanelHandle, allocator)
	assert(err == runtime.Allocator_Error.None)

	scene: Scene = {
		allocator           = allocator,
		uuid                = core.uuid_create(allocator),
		panels              = panels,
		clicks              = make([dynamic]Click, allocator),
		is_following_window = true,
	}

	root_panel := panel_create(EMPTY_HANDLE, "root", rect, PanelSpec{}, allocator)
	root_panel.ignore_events = true

	root_handle, err_2 := handle_map.add(&scene.panels, root_panel)
	assert(err_2 == runtime.Allocator_Error.None)

	scene.root_handle = root_handle
	scene.name = name

	return scene
}

scene_add_panel :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
) -> PanelHandle {
	if parent_handle == EMPTY_HANDLE do return EMPTY_HANDLE

	panel := panel_create(parent_handle, name, rect, spec, scene.allocator)
	panel_handle, err := handle_map.add(&scene.panels, panel)
	assert(err == runtime.Allocator_Error.None)


	parent := handle_map.get(scene.panels, parent_handle)
	append(&parent.children_handles, panel_handle)
	return panel_handle
}

scene_get_panel :: proc(scene: ^Scene, handle: PanelHandle) -> ^Panel {
	return handle_map.get(scene.panels, handle)
}

scene_find_panel :: proc(scene: ^Scene, root: PanelHandle, name: string) -> PanelHandle {
	panel := scene_get_panel(scene, root)
	if panel == nil do return EMPTY_HANDLE
	if panel.name == name do return root

	for child_handle in panel.children_handles {
		if found := scene_find_panel(scene, child_handle, name); found != EMPTY_HANDLE do return found
	}

	return EMPTY_HANDLE
}

scene_remove_panel :: proc(scene: ^Scene, handle: PanelHandle) {
	panel := scene_get_panel(scene, handle)
	if panel == nil do return

	if parent := scene_get_panel(scene, panel.parent_handle); parent != nil {
		for child_handle, i in parent.children_handles {
			if child_handle == handle {
				ordered_remove(&parent.children_handles, i)
				break
			}
		}
	}

	panel_destroy(scene, panel)

	scene_clear_input(scene)
	clear(&scene.clicks)
}

scene_handle_event :: proc(scene: ^Scene, event: platform.Event) -> bool {
	#partial switch e in event {
	case platform.ResizeEvent:
		if scene.is_following_window {
			root := scene_get_panel(scene, scene.root_handle)
			root.rect = core.Rect{0, 0, f32(e.info.logical_width), f32(e.info.logical_height)}
		}
		return false
	case platform.MouseMoveEvent:
		hit := scene_interaction_target(
			scene,
			panel_hit_test(scene.root_handle, scene, e.position),
		)
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
		hit := scene_interaction_target(
			scene,
			panel_hit_test(scene.root_handle, scene, e.position),
		)
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
			panel := scene_get_panel(scene, hit)
			action := ""

			if button, is_button := panel.spec.(ButtonSpec); is_button {
				action = button.action
			}

			append(
				&scene.clicks,
				Click {
					panel_handle = hit,
					panel_name = panel.name,
					button = e.button,
					count = e.clicks,
					action = action,
				},
			)
		}
		return was != EMPTY_HANDLE
	}

	return false
}

@(private)
scene_interaction_target :: proc(scene: ^Scene, hit: PanelHandle) -> PanelHandle {
	current := hit
	for current != EMPTY_HANDLE {
		panel := scene_get_panel(scene, current)
		if panel == nil do break
		if _, is_button := panel.spec.(ButtonSpec); is_button do return current
		current = panel.parent_handle
	}

	return hit
}

scene_drain_clicks :: proc(scene: ^Scene, allocator := context.temp_allocator) -> []Click {
	out := make([]Click, len(scene.clicks), allocator)

	copy(out, scene.clicks[:])
	for &click in out {
		click.panel_name = strings.clone(click.panel_name, allocator)
		click.action = strings.clone(click.action, allocator)
	}

	clear(&scene.clicks)
	return out
}

scene_clear_input :: proc(scene: ^Scene) {
	if panel := scene_get_panel(scene, scene.hovered_handle); panel != nil do panel.hovered = false
	if panel := scene_get_panel(scene, scene.pressed_handle); panel != nil do panel.pressed = false
	scene.hovered_handle = EMPTY_HANDLE
	scene.pressed_handle = EMPTY_HANDLE
}

scene_clear_hover :: proc(scene: ^Scene) {
	if panel := scene_get_panel(scene, scene.hovered_handle); panel != nil do panel.hovered = false
	scene.hovered_handle = EMPTY_HANDLE
}

scene_render :: proc(renderer: ^render.Renderer, scene: ^Scene) {
	panel_render(renderer, scene, scene.root_handle)
}

scene_destroy :: proc(scene: ^Scene) {
	panel_destroy(scene, handle_map.get(scene.panels, scene.root_handle))

	delete(scene.clicks)
	handle_map.delete(&scene.panels)
	delete(scene.uuid, scene.allocator)
}
