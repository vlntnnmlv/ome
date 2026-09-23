package omeui

import "base:builtin"
import "core:mem"
import "core:strings"

import "ome:core"
import "ome:handle_map"
import "ome:render"

PanelHandle :: distinct handle_map.Handle

EMPTY_HANDLE :: PanelHandle{}

Panel :: struct {
	uuid:             string,
	handle:           PanelHandle,
	parent_handle:    PanelHandle,
	children_handles: [dynamic]PanelHandle,
	bindings:         [dynamic]Binding,
	name:             string,
	rect:             core.Rect,
	spec:             Spec,
	ignore_events:    bool,
	hovered:          bool,
	pressed:          bool,
}

PanelDesc :: struct {
	uuid:     string,
	handle:   PanelHandle,
	name:     string,
	rect:     core.Rect,
	spec:     Spec,
	children: [dynamic]PanelDesc,
	bindings: [dynamic]Binding,
}

panel_create :: proc(
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator := context.allocator,
) -> Panel {
	return panel_create_raw(
		parent_handle = parent_handle,
		uuid = core.uuid_create(allocator),
		name = strings.clone(name, allocator),
		rect = rect,
		spec = spec_clone(spec, allocator),
		allocator = allocator,
	)
}

@(private)
panel_create_raw :: proc(
	uuid: string,
	parent_handle: PanelHandle,
	name: string,
	rect: core.Rect,
	spec: Spec,
	allocator: mem.Allocator = context.allocator,
) -> Panel {
	return Panel {
		uuid = uuid,
		parent_handle = parent_handle,
		children_handles = make([dynamic]PanelHandle, allocator),
		bindings = make([dynamic]Binding, allocator),
		name = name,
		rect = rect,
		spec = spec,
	}
}

panel_to_desc :: proc(
	scene: ^Scene,
	handle: PanelHandle,
	allocator: mem.Allocator = context.allocator,
) -> PanelDesc {
	panel := handle_map.get(scene.panels, handle)
	panel_flat := PanelDesc {
		panel.uuid,
		handle,
		panel.name,
		panel.rect,
		panel.spec,
		make([dynamic]PanelDesc, allocator),
		make([dynamic]Binding, allocator),
	}

	for child_handle in panel.children_handles {
		child_flat := panel_to_desc(scene, child_handle, allocator)
		append(&panel_flat.children, child_flat)
	}

	for binding in panel.bindings {
		append(&panel_flat.bindings, binding)
	}

	return panel_flat
}

panel_from_desc :: proc(
	scene: ^Scene,
	parent_handle: PanelHandle,
	panel_flat: PanelDesc,
) -> PanelHandle {
	panel := panel_create_raw(
		panel_flat.uuid == "" ? core.uuid_create(scene.allocator) : strings.clone(panel_flat.uuid, scene.allocator),
		parent_handle,
		strings.clone(panel_flat.name, scene.allocator),
		panel_flat.rect,
		spec_clone(panel_flat.spec, scene.allocator),
		scene.allocator,
	)

	for binding in panel_flat.bindings {
		append(
			&panel.bindings,
			Binding{target = binding.target, path = strings.clone(binding.path, scene.allocator)},
		)
	}

	handle, err := handle_map.add(&scene.panels, panel)
	assert(err == mem.Allocator_Error.None)

	if parent_handle != EMPTY_HANDLE {
		parent := scene_get_panel(scene, parent_handle)
		assert(parent != nil)

		append(&parent.children_handles, handle)
	}

	for child in panel_flat.children {
		panel_from_desc(scene, handle, child)
	}

	return handle
}

panel_set_color :: proc(scene: ^Scene, handle: PanelHandle, color: core.Color) -> bool {
	panel := scene_get_panel(scene, handle)
	if panel == nil do return false

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
	if panel == nil do return false

	#partial switch &s in panel.spec {
	case TextSpec:
		if s.text == text do return true
		cloned := strings.clone(text, scene.allocator)
		delete(s.text, scene.allocator)
		s.text = cloned
		return true
	}
	return false
}

panel_hit_test :: proc(handle: PanelHandle, scene: ^Scene, position: [2]f32) -> PanelHandle {
	if handle == EMPTY_HANDLE {
		return EMPTY_HANDLE
	}

	panel := handle_map.get(scene.panels, handle)
	if panel == nil do return EMPTY_HANDLE

	if !core.contains(panel.rect, position) {
		return EMPTY_HANDLE
	}

	#reverse for child_handle in panel.children_handles {
		if hit := panel_hit_test(child_handle, scene, position); hit != EMPTY_HANDLE {
			return hit
		}
	}

	return EMPTY_HANDLE if panel.ignore_events else handle
}

panel_render :: proc(renderer: ^render.Renderer, scene: ^Scene, handle: PanelHandle) {
	panel := handle_map.get(scene.panels, handle)

	if scene.is_debug {
		color := core.Color{255, 0, 0, 255}
		if panel.hovered do color = core.Color{0, 255, 0, 255}
		if panel.pressed do color = core.Color{0, 0, 255, 255}
		render.quad(renderer, panel.rect, color, 1, false)
	}

	switch spec in panel.spec {
	case PanelSpec:
		break
	case ButtonSpec:
		render.quad(renderer, panel.rect, spec.color, 1, false)
	case TextSpec:
		render.text(renderer, spec.text, spec.font_handle, spec.font_size, panel.rect, spec.color)
	case ImageSpec:
		render.texture_by_atlas_name(
			renderer,
			spec.atlas_handle,
			spec.sprite_name,
			panel.rect,
			spec.color,
			spec.slice_offset,
		)
	}

	for child_handle in panel.children_handles {
		panel_render(renderer, scene, child_handle)
	}
}

panel_destroy :: proc(scene: ^Scene, panel: ^Panel) {
	if panel == nil do return

	for binding in panel.bindings {
		delete(binding.path, scene.allocator)
	}

	delete(panel.bindings)

	for child_handle in panel.children_handles {
		panel_destroy(scene, scene_get_panel(scene, child_handle))
	}
	handle_map.remove(&scene.panels, panel.handle)

	spec_destroy(panel.spec, scene.allocator)
	delete(panel.name, scene.allocator)
	delete(panel.uuid, scene.allocator)
	builtin.delete(panel.children_handles)
}
