package omeui

import "ome:core"
Sizing :: union #no_nil {
	Fit,
	Fixed,
	Fill,
}
Fixed :: distinct f32
Fit :: struct {}
Fill :: distinct f32

Align :: enum {
	Start = 0,
	Center,
	End,
}

Axis :: enum {
	Horizontal = 0,
	Vertical,
}

Layout :: struct {
	// child
	width, height: Sizing,
	min, max:      [2]f32,
	align:         Align,
	// container
	axis:          Axis,
	padding:       core.RectOffset,
	spacing:       f32,
	content_align: Align,
}

@(private)
scene_update_layout :: proc(scene: ^Scene) {
	if !scene.layout_dirty {
		return
	}
	scene.layout_dirty = false

	layout_measure(scene, scene.root_handle)
	root := scene_get_panel(scene, scene.root_handle)
	layout_arrange(
		scene,
		scene.root_handle,
		{root.rect.x, root.rect.y, root.desired.x, root.desired.y},
	)
}

@(private)
layout_sizing :: proc(layout: Layout, axis: Axis) -> Sizing {
	return layout.width if axis == .Horizontal else layout.height
}

@(private)
layout_measure :: proc(scene: ^Scene, handle: PanelHandle) {
	panel := scene_get_panel(scene, handle)
	for child_handle in panel.child_handles {
		layout_measure(scene, child_handle)
	}

	for axis in Axis {
		value: f32
		switch sizing in layout_sizing(panel.layout, axis) {
		case Fit:
			value = 0
		case Fixed:
			value = f32(sizing)
		case Fill:
			value = 0
		}
		panel.desired[axis] = value
	}
}

@(private)
layout_arrange :: proc(scene: ^Scene, handle: PanelHandle, rect: core.Rect) {
	panel := scene_get_panel(scene, handle)
	panel.rect = rect

	layout := panel.layout
	inner_rect := core.rect_shrink(rect, layout.padding)
	position := [2]f32{inner_rect.x, inner_rect.y}
	m := int(layout.axis)
	c := 1 - m

	cursor := position[m]
	for child_handle in panel.child_handles {
		child := scene_get_panel(scene, child_handle)
		size := child.desired
		child_position: [2]f32
		child_position[m] = cursor
		child_position[c] = position[c]
		layout_arrange(scene, child_handle, {child_position.x, child_position.y, size.x, size.y})
		cursor += size[m] + layout.spacing
	}
}
