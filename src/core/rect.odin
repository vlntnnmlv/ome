package omecore

Rect :: struct {
	x, y, w, h: f32,
}

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
