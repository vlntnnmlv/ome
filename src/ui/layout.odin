package omeui

import "ome:assets"
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
	Start,
	Center,
	End,
}

Layout :: struct {
	// child
	size:          [core.Axis]Sizing,
	min, max:      [core.Axis]f32,
	align:         Align,
	margin:        core.RectOffset,
	// container
	direction:     core.Axis,
	padding:       core.RectOffset,
	spacing:       f32,
	content_align: Align,
}

@(private)
outer_size :: proc(panel: ^Panel) -> [core.Axis]f32 {
	margin := core.rect_offset_total(panel.layout.margin)
	return {.X = panel.desired[.X] + margin[.X], .Y = panel.desired[.Y] + margin[.Y]}
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
		{root.rect.x, root.rect.y, root.desired[.X], root.desired[.Y]},
	)
}

@(private)
layout_measure :: proc(scene: ^Scene, handle: PanelHandle) {
	panel := scene_get_panel(scene, handle)
	for child_handle in panel.child_handles {
		layout_measure(scene, child_handle)
	}

	content := measure_children(scene, panel)
	intrinsic := layout_intrinsic(scene, panel)
	padding := core.rect_offset_total(panel.layout.padding)

	for axis in core.Axis {
		natural := max(content[axis], intrinsic[axis]) + padding[axis]
		desired := sizing_resolve(panel.layout.size[axis], natural)
		panel.desired[axis] = clamp_size(desired, panel.layout.min[axis], panel.layout.max[axis])
	}
}

@(private)
measure_children :: proc(scene: ^Scene, panel: ^Panel) -> [core.Axis]f32 {
	along := panel.layout.direction
	across := core.axis_cross(along)

	content: [core.Axis]f32
	for child_handle in panel.child_handles {
		child := scene_get_panel(scene, child_handle)
		outer := outer_size(child)
		content[along] += outer[along]
		content[across] = max(content[across], outer[across])
	}

	content[along] += total_spacing(panel)
	return content
}

@(private)
sizing_resolve :: proc(sizing: Sizing, natural: f32) -> f32 {
	switch s in sizing {
	case Fit, Fill:
		return natural
	case Fixed:
		return f32(s)
	}

	return natural
}

@(private)
clamp_size :: proc(value, min_value, max_value: f32) -> f32 {
	v := max(value, min_value)
	return min(v, max_value) if max_value > 0 else v
}

@(private)
total_spacing :: proc(panel: ^Panel) -> f32 {
	n := len(panel.child_handles)
	return panel.layout.spacing * f32(n - 1) if n > 1 else 0
}

@(private)
layout_arrange :: proc(scene: ^Scene, handle: PanelHandle, rect: core.Rect) {
	panel := scene_get_panel(scene, handle)
	panel.rect = rect

	layout := panel.layout
	along := layout.direction
	across := core.axis_cross(along)

	content_box := core.rect_shrink(rect, layout.padding)
	origin := core.rect_position(content_box)
	available := core.rect_size(content_box)

	free_space, fill_weight := free_space_along(scene, panel, available[along])

	cursor := origin[along]
	if fill_weight == 0 {
		cursor += align_offset(layout.content_align, free_space)
	}

	for child_handle in panel.child_handles {
		child := scene_get_panel(scene, child_handle)

		margin_start := core.rect_offset_start(child.layout.margin)
		margin_total := core.rect_offset_total(child.layout.margin)
		slot_across := available[across] - margin_total[across]

		size: [core.Axis]f32
		size[along] = size_along(child, along, free_space, fill_weight)
		size[across] = size_across(child, across, slot_across)

		position: [core.Axis]f32
		position[along] = cursor + margin_start[along]
		position[across] =
			origin[across] +
			margin_start[across] +
			align_offset(child.layout.align, slot_across - size[across])

		layout_arrange(scene, child_handle, core.rect_from(position, size))
		cursor += size[along] + margin_total[along] + layout.spacing
	}
}

@(private)
free_space_along :: proc(
	scene: ^Scene,
	panel: ^Panel,
	available: f32,
) -> (
	free_space, fill_weight: f32,
) {
	along := panel.layout.direction
	occupied := total_spacing(panel)
	for child_handle in panel.child_handles {
		child := scene_get_panel(scene, child_handle)
		occupied += outer_size(child)[along]
		if weight, is_fill := child.layout.size[along].(Fill); is_fill {
			fill_weight += f32(weight)
		}
	}

	return max(available - occupied, 0), fill_weight
}

@(private)
size_along :: proc(child: ^Panel, along: core.Axis, free_space, fill_weight: f32) -> f32 {
	size := child.desired[along]
	if weight, is_fill := child.layout.size[along].(Fill); is_fill && fill_weight > 0 {
		size += free_space * f32(weight) / fill_weight
	}
	return clamp_size(size, child.layout.min[along], child.layout.max[along])
}

@(private)
size_across :: proc(child: ^Panel, across: core.Axis, available: f32) -> f32 {
	size := child.desired[across]
	if _, is_fill := child.layout.size[across].(Fill); is_fill {
		size = max(size, available)
	}

	return clamp_size(size, child.layout.min[across], child.layout.max[across])
}

@(private)
layout_intrinsic :: proc(scene: ^Scene, panel: ^Panel) -> [core.Axis]f32 {
	#partial switch spec in panel.spec {
	case TextSpec:
		font := assets.library_get_font(scene.library, spec.font_handle)
		if font == nil {
			return {}
		}
		size := assets.font_text_measure(font, spec.text, spec.font_size)
		return {.X = size.x, .Y = size.y}
	case ImageSpec:
		atlas := assets.library_get_atlas(scene.library, spec.atlas_handle)
		if atlas == nil {
			return {}
		}
		sprite, found := atlas.sprites[spec.sprite_name]
		if !found {
			return {}
		}
		return {.X = sprite.atlas_rect.w, .Y = sprite.atlas_rect.h}
	}

	return {}
}

@(private)
align_offset :: proc(align: Align, space: f32) -> f32 {
	switch align {
	case .Start:
		return 0
	case .Center:
		return space * 0.5
	case .End:
		return space
	}
	return 0
}
