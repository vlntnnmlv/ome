package omeui

import "core:testing"

@(test)
test_fill_ratio :: proc(t: ^testing.T) {
	tree: LayoutTree
	defer delete(tree.nodes)

	append(
		&tree.nodes,
		LayoutNode {
			parent = -1,
			first_child = 1,
			child_count = 2,
			layout = {flow = .Row, size = {.X = Fixed(300), .Y = Fixed(10)}},
		},
		LayoutNode{parent = 0, layout = {size = {.X = Fill(1), .Y = Fit{}}}},
		LayoutNode{parent = 0, layout = {size = {.X = Fill(2), .Y = Fit{}}}},
	)
	layout_solve(&tree)

	testing.expect_value(t, tree.nodes[1].size[.X], 100)
	testing.expect_value(t, tree.nodes[2].size[.X], 200)
}
