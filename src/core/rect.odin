package omecore

RectOffset :: struct {
	left, right, top, bottom: f32,
}

Rect :: struct {
	x, y, w, h: f32,
}

Span :: struct {
	start, size: f32,
}

Axis :: enum u8 {
	X,
	Y,
}

Flip :: bit_set[Axis;u8]

UNIT_RECT :: Rect{0, 0, 1, 1}
ZERO_RECT :: Rect{0, 0, 0, 0}
ZERO_RECT_OFFSET :: RectOffset{0, 0, 0, 0}


rect_shrink :: proc(rect: Rect, rect_offset: RectOffset) -> Rect {
	return Rect {
		rect.x + rect_offset.left,
		rect.y + rect_offset.top,
		rect.w - rect_offset.left - rect_offset.right,
		rect.h - rect_offset.bottom - rect_offset.top,
	}
}

rect_contains :: proc(rect: Rect, position: [2]f32) -> bool {
	return(
		position.x >= rect.x &&
		position.x <= rect.x + rect.w &&
		position.y >= rect.y &&
		position.y <= rect.y + rect.h \
	)
}

rect_split_to_grid :: proc(rect: Rect, offset: RectOffset) -> [9]Rect {
	xs := [4]f32{rect.x, rect.x + offset.left, rect.x + rect.w - offset.right, rect.x + rect.w}
	ys := [4]f32{rect.y, rect.y + offset.top, rect.y + rect.h - offset.bottom, rect.y + rect.h}

	cells: [9]Rect
	for row in 0 ..< 3 {
		for col in 0 ..< 3 {
			cells[row * 3 + col] = Rect {
				xs[col],
				ys[row],
				xs[col + 1] - xs[col],
				ys[row + 1] - ys[row],
			}
		}
	}
	return cells
}

rect_union :: proc(a, b: Rect) -> Rect {
	if a.w <= 0 || a.h <= 0 {return b}
	if b.w <= 0 || b.h <= 0 {return a}

	x0 := min(a.x, b.x)
	y0 := min(a.y, b.y)
	x1 := max(a.x + a.w, b.x + b.w)
	y1 := max(a.y + a.h, b.y + b.h)
	return Rect{x0, y0, x1 - x0, y1 - y0}
}

rect_offset_sides :: proc(offset: RectOffset, axis: Axis) -> (start, end: f32) {
	switch axis {
	case .X:
		start = offset.left; end = offset.right
	case .Y:
		start = offset.top; end = offset.bottom
	}

	return
}

rect_offset_axis :: proc(offset: RectOffset, axis: Axis) -> f32 {
	start, end := rect_offset_sides(offset, axis)
	return start + end
}

rect_offset_flip :: proc(offset: RectOffset, flip: Flip) -> RectOffset {
	res := RectOffset(offset)

	if .X in flip {c := res.left; res.left = res.right; res.right = c}
	if .Y in flip {c := res.top; res.top = res.bottom; res.bottom = c}

	return res
}
