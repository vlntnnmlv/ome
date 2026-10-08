package omeui

import "ome:core"

// Nodes are in BFS order: parent index < child index, siblings contiguous.
// Reverse iteration = bottom-up (children before parent).
// Forward iteration = top-down (parent before children).
LayoutTree :: struct {
	nodes: [dynamic]LayoutNode,
}

LayoutNode :: struct {
	handle:        PanelHandle,
	first_child:   int,
	child_count:   int,
	layout:        Layout,
	intrinsic:     [core.Axis]f32,
	intrinsic_min: [core.Axis]f32,
	min_size:      [core.Axis]f32,
	size:          [core.Axis]f32,
	position:      [core.Axis]f32,
}

@(private)
layout_build :: proc(tree: ^LayoutTree, scene: ^Scene) {
	clear(&tree.nodes)
	append(&tree.nodes, layout_node_make(scene, scene.root_handle, -1))

	for i := 0; i < len(tree.nodes); i += 1 {
		panel := scene_get_panel(scene, tree.nodes[i].handle)
		tree.nodes[i].first_child = len(tree.nodes)
		tree.nodes[i].child_count = len(panel.child_handles)
		for child_handle in panel.child_handles {
			append(&tree.nodes, layout_node_make(scene, child_handle, i))
		}
	}
}

@(private)
layout_node_make :: proc(scene: ^Scene, handle: PanelHandle, parent: int) -> LayoutNode {
	panel := scene_get_panel(scene, handle)
	intrinsic, intrinsic_min := layout_measure_content(scene, panel)

	return LayoutNode {
		handle = handle,
		layout = panel.layout,
		intrinsic = intrinsic,
		intrinsic_min = intrinsic_min,
	}
}

@(private)
layout_write_back :: proc(tree: ^LayoutTree, scene: ^Scene) {
	for node in tree.nodes {
		panel := scene_get_panel(scene, node.handle)
		panel.rect = {node.position[.X], node.position[.Y], node.size[.X], node.size[.Y]}
	}
}

@(private)
layout_node_children :: proc(tree: ^LayoutTree, node: LayoutNode) -> []LayoutNode {
	return tree.nodes[node.first_child:node.first_child + node.child_count]
}
