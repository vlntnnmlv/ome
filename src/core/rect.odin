package omecore

RectOffset :: struct {
	left, right, top, bottom: f32,
}

Rect :: struct {
	x, y, w, h: f32,
}

UNIT_RECT :: Rect{0, 0, 1, 1}
ZERO_RECT :: Rect{0, 0, 0, 0}
ZERO_RECT_OFFSET :: RectOffset{0, 0, 0, 0}


shrink :: proc(rect: Rect, rect_offset: RectOffset) -> Rect {
	return Rect {
		rect.x + rect_offset.left,
		rect.y + rect_offset.top,
		rect.w - rect_offset.left - rect_offset.right,
		rect.h - rect_offset.bottom - rect_offset.top,
	}
}

contains :: proc(rect: Rect, position: [2]f32) -> bool {
	return(
		position.x >= rect.x &&
		position.x <= rect.x + rect.w &&
		position.y >= rect.y &&
		position.y <= rect.y + rect.h \
	)
}

split_to_grid :: proc(rect: Rect, offset: RectOffset) -> [9]Rect {
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
