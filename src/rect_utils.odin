package ome

shrink :: proc(rect: Rect, rect_offset: RectOffset) -> Rect {
	return Rect {
		rect.x + rect_offset.left,
		rect.y + rect_offset.bottom,
		rect.w - rect_offset.left - rect_offset.right,
		rect.h - rect_offset.bottom - rect_offset.top,
	}
}
