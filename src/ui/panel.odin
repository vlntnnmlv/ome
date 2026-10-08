package omeui

import "core:mem"
import "core:strings"

import "ome:core"
import "ome:handle_map"
import "ome:render"

PanelHandle :: distinct handle_map.Handle

NO_PANEL :: PanelHandle{}

Panel :: struct {
	uuid:          string,
	handle:        PanelHandle,
	parent_handle: PanelHandle,
	child_handles: [dynamic]PanelHandle,
	bindings:      [dynamic]Binding,
	name:          string,
	rect:          core.Rect,
	spec:          Spec,
	ignore_events: bool,
	hovered:       bool,
	pressed:       bool,
	layout:        Layout,
}

PanelDescription :: struct {
	uuid:     string,
	handle:   PanelHandle,
	name:     string,
	spec:     Spec,
	layout:   Layout,
	children: [dynamic]PanelDescription,
	bindings: [dynamic]Binding,
}

panel_create :: proc(
	parent_handle: PanelHandle,
	name: string,
	spec: Spec,
	layout: Layout,
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return panel_create_raw(
		parent_handle = parent_handle,
		uuid = core.uuid_create(allocator),
		name = strings.clone(name, allocator),
		spec = spec_clone(spec, allocator),
		layout = layout,
		allocator = allocator,
	)
}

@(private)
panel_create_raw :: proc(
	parent_handle: PanelHandle,
	uuid: string,
	name: string,
	spec: Spec,
	layout: Layout,
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return Panel {
		uuid = uuid,
		parent_handle = parent_handle,
		child_handles = make([dynamic]PanelHandle, allocator),
		bindings = make([dynamic]Binding, allocator),
		name = name,
		layout = layout,
		spec = spec,
	}
}

panel_to_description :: proc(
	scene: ^Scene,
	handle: PanelHandle,
	allocator: mem.Allocator = context.allocator,
) -> PanelDescription {
	panel := handle_map.get(scene.panels, handle)
	panel_description := PanelDescription {
		panel.uuid,
		handle,
		panel.name,
		panel.spec,
		panel.layout,
		make([dynamic]PanelDescription, allocator),
		make([dynamic]Binding, allocator),
	}

	for child_handle in panel.child_handles {
		child_description := panel_to_description(scene, child_handle, allocator)
		append(&panel_description.children, child_description)
	}

	for binding in panel.bindings {
		append(&panel_description.bindings, binding)
	}

	return panel_description
}

panel_from_description :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	panel_description: PanelDescription,
) -> PanelHandle {
	uuid: string
	if panel_description.uuid == "" {
		uuid = core.uuid_create(scene.allocator)
	} else {
		err: mem.Allocator_Error
		uuid, err = strings.clone(panel_description.uuid, scene.allocator)
		ensure(err == nil)
	}

	panel := panel_create_raw(
		parent_handle,
		uuid,
		strings.clone(panel_description.name, scene.allocator),
		spec_clone(panel_description.spec, scene.allocator),
		panel_description.layout,
		scene.allocator,
	)

	for binding in panel_description.bindings {
		append(
			&panel.bindings,
			Binding{target = binding.target, path = strings.clone(binding.path, scene.allocator)},
		)
	}

	panel_handle, err := handle_map.add(&scene.panels, panel)
	ensure(err == nil)

	if parent_handle != NO_PANEL {
		parent := scene_get_panel(scene, parent_handle)
		assert(parent != nil)

		append(&parent.child_handles, panel_handle)
	}

	for child in panel_description.children {
		panel_from_description(scene, panel_handle, child)
	}

	scene.layout_dirty = true
	return panel_handle
}

panel_set_color :: proc(scene: ^Scene, handle: PanelHandle, color: core.Color) -> bool {
	panel := scene_get_panel(scene, handle)
	if panel == nil {
		return false
	}

	switch &s in panel.spec {
	case PanelSpec:
		s.color = color
	case ImageSpec:
		s.color = color
	case ButtonSpec:
		s.color = color
	case TextSpec:
		s.color = color
	}
	return true
}

panel_set_text :: proc(scene: ^Scene, handle: PanelHandle, text: string) -> bool {
	panel := scene_get_panel(scene, handle)
	if panel == nil {
		return false
	}

	#partial switch &s in panel.spec {
	case TextSpec:
		if s.text == text {
			return true
		}
		cloned := strings.clone(text, scene.allocator)
		delete(s.text, scene.allocator)
		s.text = cloned
		scene.layout_dirty = true
		return true
	}
	return false
}

panel_set_layout :: proc(scene: ^Scene, handle: PanelHandle, layout: Layout) -> bool {
	panel := scene_get_panel(scene, handle)
	if panel == nil || panel.layout == layout {
		return false
	}

	panel.layout = layout
	scene.layout_dirty = true
	return true
}

panel_hit_test :: proc(scene: ^Scene, handle: PanelHandle, position: [2]f32) -> PanelHandle {
	if handle == NO_PANEL {
		return NO_PANEL
	}

	panel := handle_map.get(scene.panels, handle)
	if panel == nil {
		return NO_PANEL
	}

	if !core.rect_contains(panel.rect, position) {
		return NO_PANEL
	}

	#reverse for child_handle in panel.child_handles {
		if hit_handle := panel_hit_test(scene, child_handle, position); hit_handle != NO_PANEL {
			return hit_handle
		}
	}

	if panel.ignore_events {
		return NO_PANEL
	}

	return handle
}

panel_render :: proc(scene: ^Scene, handle: PanelHandle, renderer: ^render.Renderer) {
	panel := handle_map.get(scene.panels, handle)

	if scene.debug {
		color := core.Color{255, 0, 0, 255}
		if panel.hovered {
			color = core.Color{0, 255, 0, 255}
		}
		if panel.pressed {
			color = core.Color{0, 0, 255, 255}
		}
		render.quad(renderer, panel.rect, color, 1)
	}

	switch spec in panel.spec {
	case PanelSpec:
		break
	case ButtonSpec:
		render.quad(renderer, panel.rect, spec.color, 1)
	case TextSpec:
		render.text(renderer, spec.text, spec.font_handle, spec.font_size, panel.rect, spec.color)
	case ImageSpec:
		render.sprite(
			renderer,
			spec.atlas_handle,
			spec.sprite_name,
			panel.rect,
			spec.color,
			spec.slice_offset,
			spec.flip,
		)
	}

	for child_handle in panel.child_handles {
		panel_render(scene, child_handle, renderer)
	}
}

panel_destroy :: proc(scene: ^Scene, panel: ^Panel) {
	if panel == nil {
		return
	}

	for binding in panel.bindings {
		delete(binding.path, scene.allocator)
	}

	delete(panel.bindings)

	for child_handle in panel.child_handles {
		panel_destroy(scene, scene_get_panel(scene, child_handle))
	}
	handle_map.remove(&scene.panels, panel.handle)

	spec_destroy(panel.spec, scene.allocator)
	delete(panel.name, scene.allocator)
	delete(panel.uuid, scene.allocator)
	delete(panel.child_handles)
}
