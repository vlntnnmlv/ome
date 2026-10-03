package omeui

import "core:mem"
import "core:strings"
import "ome:assets"

import "ome:core"
import "ome:handle_map"
import "ome:platform"
import "ome:render"

SceneHandle :: distinct handle_map.Handle

Scene :: struct {
	allocator:        mem.Allocator,
	uuid:             string,
	handle:           SceneHandle,
	root_handle:      PanelHandle,
	hovered_handle:   PanelHandle,
	pressed_handle:   PanelHandle,
	clicks:           [dynamic]Click,
	panels:           handle_map.Map(Panel, PanelHandle),
	name:             string,
	modal:            bool,
	following_window: bool,
	debug:            bool,
	layout_dirty:     bool,
	library:          ^assets.Library,
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
	library: ^assets.Library,
	allocator: mem.Allocator = context.allocator,
) -> Scene {
	panels, err := handle_map.make(Panel, PanelHandle, allocator)
	ensure(err == nil)

	scene: Scene = {
		allocator        = allocator,
		uuid             = core.uuid_create(allocator),
		panels           = panels,
		clicks           = make([dynamic]Click, allocator),
		following_window = true,
		library          = library,
	}

	root_panel := panel_create(
		NO_PANEL,
		"root",
		PanelSpec{},
		{size = {.X = Fixed(rect.w), .Y = Fixed(rect.h)}},
		allocator,
	)
	root_panel.ignore_events = true

	root_handle: PanelHandle
	root_handle, err = handle_map.add(&scene.panels, root_panel)
	ensure(err == nil)

	scene.layout_dirty = true
	scene.root_handle = root_handle
	scene.name = strings.clone(name, allocator)

	return scene
}

scene_add_panel :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	name: string,
	spec: Spec,
	layout: Layout,
) -> PanelHandle {
	if parent_handle == NO_PANEL {
		return NO_PANEL
	}

	panel := panel_create(parent_handle, name, spec, layout, scene.allocator)
	panel_handle, err := handle_map.add(&scene.panels, panel)
	ensure(err == nil)

	parent := handle_map.get(scene.panels, parent_handle)
	append(&parent.child_handles, panel_handle)

	scene.layout_dirty = true
	return panel_handle
}

scene_get_panel :: proc(scene: ^Scene, handle: PanelHandle) -> ^Panel {
	return handle_map.get(scene.panels, handle)
}

scene_find_panel :: proc(scene: ^Scene, root_handle: PanelHandle, name: string) -> PanelHandle {
	panel := scene_get_panel(scene, root_handle)
	if panel == nil {
		return NO_PANEL
	}
	if panel.name == name {
		return root_handle
	}

	for child_handle in panel.child_handles {
		if found := scene_find_panel(scene, child_handle, name); found != NO_PANEL {
			return found
		}
	}

	return NO_PANEL
}

scene_remove_panel :: proc(scene: ^Scene, handle: PanelHandle) {
	panel := scene_get_panel(scene, handle)
	if panel == nil {
		return
	}

	if parent := scene_get_panel(scene, panel.parent_handle); parent != nil {
		for child_handle, i in parent.child_handles {
			if child_handle == handle {
				ordered_remove(&parent.child_handles, i)
				break
			}
		}
	}

	panel_destroy(scene, panel)

	scene_clear_input(scene)
	clear(&scene.clicks)
	scene.layout_dirty = true
}

scene_handle_event :: proc(scene: ^Scene, event: platform.Event) -> bool {
	scene_update_layout(scene)

	#partial switch e in event {
	case platform.ResizeEvent:
		if scene.following_window {
			root := scene_get_panel(scene, scene.root_handle)
			root.layout.size = {
				.X = Fixed(f32(e.info.logical_width)),
				.Y = Fixed(f32(e.info.logical_height)),
			}
			scene.layout_dirty = true
		}
		return false
	case platform.MouseMoveEvent:
		hit_handle := scene_interaction_target(
			scene,
			panel_hit_test(scene, scene.root_handle, e.position),
		)
		if hit_handle != scene.hovered_handle {
			if scene.hovered_handle != NO_PANEL {
				scene_get_panel(scene, scene.hovered_handle).hovered = false
			}
			if hit_handle != NO_PANEL {
				scene_get_panel(scene, hit_handle).hovered = true
			}

			scene.hovered_handle = hit_handle
		}
		return hit_handle != NO_PANEL
	case platform.MouseButtonEvent:
		hit_handle := scene_interaction_target(
			scene,
			panel_hit_test(scene, scene.root_handle, e.position),
		)
		if e.down {
			if hit_handle != NO_PANEL {
				scene_get_panel(scene, hit_handle).pressed = true
				scene.pressed_handle = hit_handle
			}
			return hit_handle != NO_PANEL
		}

		previously_pressed_handle := scene.pressed_handle
		if previously_pressed_handle != NO_PANEL {
			scene_get_panel(scene, previously_pressed_handle).pressed = false
			scene.pressed_handle = NO_PANEL
		}

		if hit_handle != NO_PANEL && hit_handle == previously_pressed_handle {
			panel := scene_get_panel(scene, hit_handle)
			action := ""

			if button, is_button := panel.spec.(ButtonSpec); is_button {
				action = button.action
			}

			append(
				&scene.clicks,
				Click {
					panel_handle = hit_handle,
					panel_name = panel.name,
					button = e.button,
					count = e.clicks,
					action = action,
				},
			)
		}
		return previously_pressed_handle != NO_PANEL
	}

	return false
}

@(private)
scene_interaction_target :: proc(scene: ^Scene, hit_handle: PanelHandle) -> PanelHandle {
	current_handle := hit_handle
	for current_handle != NO_PANEL {
		panel := scene_get_panel(scene, current_handle)
		if panel == nil {
			break
		}
		if _, is_button := panel.spec.(ButtonSpec); is_button {
			return current_handle
		}
		current_handle = panel.parent_handle
	}

	return hit_handle
}

scene_drain_clicks :: proc(
	scene: ^Scene,
	allocator: mem.Allocator = context.temp_allocator,
) -> []Click {
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
	if panel := scene_get_panel(scene, scene.hovered_handle); panel != nil {
		panel.hovered = false
	}
	if panel := scene_get_panel(scene, scene.pressed_handle); panel != nil {
		panel.pressed = false
	}
	scene.hovered_handle = NO_PANEL
	scene.pressed_handle = NO_PANEL
}

scene_clear_hover :: proc(scene: ^Scene) {
	if panel := scene_get_panel(scene, scene.hovered_handle); panel != nil {
		panel.hovered = false
	}
	scene.hovered_handle = NO_PANEL
}

scene_render :: proc(scene: ^Scene, renderer: ^render.Renderer) {
	scene_update_layout(scene)

	panel_render(scene, scene.root_handle, renderer)
}

scene_destroy :: proc(scene: ^Scene) {
	panel_destroy(scene, handle_map.get(scene.panels, scene.root_handle))

	delete(scene.clicks)
	delete(scene.name, scene.allocator)
	handle_map.delete(&scene.panels)
	delete(scene.uuid, scene.allocator)
}
