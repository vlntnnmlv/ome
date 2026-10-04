package omeui

import "ome:core"
@(private)
layout_solve :: proc(tree: ^LayoutTree) {
	pass_fit(tree, .X)
	pass_grow(tree, .X)
	// pass_wrap(tree)
	pass_fit(tree, .Y)
	pass_grow(tree, .Y)
	pass_position(tree)
}

@(private)
pass_fit :: proc(tree: ^LayoutTree, axis: core.Axis) {
	#reverse for &node in tree.nodes {
		layout := node.layout
		children := layout_node_children(tree, node)
		stacks := flow_stacks(layout.flow, axis)

		content, content_min: f32
		for child in children {
			margin := core.rect_offset_axis(child.layout.margin, axis)
			if stacks {
				content += child.size[axis] + margin
				content_min += child.min_size[axis] + margin
			} else {
				content = max(content, child.size[axis] + margin)
				content_min = max(content_min, child.min_size[axis] + margin)
			}
		}

		if stacks {
			content += spacing_total(layout.spacing, len(children))
			content_min += spacing_total(layout.spacing, len(children))
		}

		padding := core.rect_offset_axis(layout.padding, axis)
		size := max(content, node.intrinsic[axis]) + padding
		min_size := max(content_min, node.intrinsic_min[axis]) + padding

		if fixed, is_fixed := layout.size[axis].(Fixed); is_fixed {
			size = f32(fixed)
			min_size = f32(fixed)
		}

		node.size[axis] = clamp_size(size, layout.min[axis], layout.max[axis])
		node.min_size[axis] = clamp_size(min_size, layout.min[axis], layout.max[axis])
	}
}

@(private)
pass_grow :: proc(tree: ^LayoutTree, axis: core.Axis) {
	for node in tree.nodes {
		children := layout_node_children(tree, node)
		if len(children) == 0 {
			continue
		}

		available := node.size[axis] - core.rect_offset_axis(node.layout.padding, axis)
		if flow_stacks(node.layout.flow, axis) {
			grow_stack(children, axis, available, node.layout.spacing)
		} else {
			grow_overlap(children, axis, available)
		}
	}
}

@(private)
grow_stack :: proc(children: []LayoutNode, axis: core.Axis, available, spacing: f32) {
	occupied := spacing_total(spacing, len(children))
	fill_weight: f32
	for child in children {
		occupied += child.size[axis] + core.rect_offset_axis(child.layout.margin, axis)
		if weight, is_fill := child.layout.size[axis].(Fill); is_fill {
			fill_weight += f32(weight)
		}
	}

	free_space := available - occupied
	if free_space < 0 {
		shrink_stack(children, axis, -free_space)
		return
	}

	if fill_weight == 0 {
		return
	}

	for &child in children {
		if weight, is_fill := child.layout.size[axis].(Fill); is_fill {
			grown := child.size[axis] + free_space * f32(weight) / fill_weight
			child.size[axis] = clamp_size(grown, child.layout.min[axis], child.layout.max[axis])
		}
	}
}

@(private)
shrink_stack :: proc(children: []LayoutNode, axis: core.Axis, overflow: f32) {
	slack: f32
	for child in children {
		if is_shrinkable(child.layout.size[axis]) {
			slack += child.size[axis] - child.min_size[axis]
		}
	}

	if slack <= 0 {
		return
	}

	ratio := min(overflow / slack, 1)
	for &child in children {
		if is_shrinkable(child.layout.size[axis]) {
			child.size[axis] -= (child.size[axis] - child.min_size[axis]) * ratio
		}
	}
}

@(private)
is_shrinkable :: proc(sizing: Sizing) -> bool {
	_, is_fixed := sizing.(Fixed)
	return !is_fixed
}

@(private)
grow_overlap :: proc(children: []LayoutNode, axis: core.Axis, available: f32) {
	for &child in children {
		sizing := child.layout.size[axis]
		room := available - core.rect_offset_axis(child.layout.margin, axis)

		size := child.size[axis]
		if _, is_fill := sizing.(Fill); is_fill {
			size = room
		} else if size > room && is_shrinkable(sizing) {
			size = room
		}

		size = max(size, child.min_size[axis])
		child.size[axis] = clamp_size(size, child.layout.min[axis], child.layout.max[axis])
	}
}

@(private)
pass_position :: proc(tree: ^LayoutTree) {
	for node in tree.nodes {
		children := layout_node_children(tree, node)
		for axis in core.Axis {
			padding_start, padding_end := core.rect_offset_sides(node.layout.padding, axis)
			slot := core.Span {
				node.position[axis] + padding_start,
				node.size[axis] - padding_start - padding_end,
			}
			if flow_stacks(node.layout.flow, axis) {
				position_stack(
					children,
					axis,
					slot,
					node.layout.spacing,
					node.layout.content_align,
				)
			} else {
				position_overlap(children, axis, slot)
			}
		}
	}
}

@(private)
position_stack :: proc(
	children: []LayoutNode,
	axis: core.Axis,
	slot: core.Span,
	spacing: f32,
	content_align: Align,
) {
	occupied := spacing_total(spacing, len(children))
	for child in children {
		occupied += child.size[axis] + core.rect_offset_axis(child.layout.margin, axis)
	}

	cursor := slot.start + align_offset(content_align, max(slot.size - occupied, 0))
	for &child in children {
		margin_start, margin_end := core.rect_offset_sides(child.layout.margin, axis)
		child.position[axis] = cursor + margin_start
		cursor += margin_start + child.size[axis] + margin_end + spacing
	}
}

@(private)
position_overlap :: proc(children: []LayoutNode, axis: core.Axis, slot: core.Span) {
	for &child in children {
		margin_start, margin_end := core.rect_offset_sides(child.layout.margin, axis)
		room := slot.size - margin_start - margin_end
		child.position[axis] =
			slot.start +
			margin_start +
			align_offset(child.layout.align[axis], room - child.size[axis])
	}
}

@(private)
flow_stacks :: proc(flow: Flow, axis: core.Axis) -> bool {
	switch flow {
	case .Row:
		return axis == .X
	case .Column:
		return axis == .Y
	case .Overlay:
		return false
	}

	return false
}

@(private)
clamp_size :: proc(value, min_value, max_value: f32) -> f32 {
	v := max(value, min_value)
	return min(v, max_value) if max_value > 0 else v
}

@(private)
spacing_total :: proc(spacing: f32, count: int) -> f32 {
	return spacing * f32(count - 1) if count > 1 else 0
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
