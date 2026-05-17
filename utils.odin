#+private

package ome

get_n_colors_rainbow :: proc(count: int) -> []Color {
	colors: [dynamic]Color = {}
	for i in 0 ..< count {
		append(
			&colors,
			cast(Color)[4]int{int(i % 3 == 0), int((i + 2) % 3 == 0), int((i + 1) % 3 == 0), 1},
		)
	}

	return colors[:]
}

get_n_colors_dupe :: proc(color: Color, count: int) -> []Color {
	colors: [dynamic]Color = {}
	for _ in 0 ..< count {
		append(&colors, color)
	}

	return colors[:]
}

get_n_colors :: proc(color: Maybe(Color), count: int) -> []Color {
	if real_color, ok := color.?; !ok {
		return get_n_colors_rainbow(count)
	} else {
		return get_n_colors_dupe(real_color, count)
	}
}

screen2world :: proc(x: f32, y: f32) -> [2]f32 {
	px := x * app.pixel_ratio
	py := y * app.pixel_ratio
	size := [2]f32{cast(f32)app.width, cast(f32)app.height}
	point := [2]f32{px, py}
	return (point - size / 2) * 2 / size
}

rect2vertices :: proc(rect: Rect) -> [6]Vertex {
	positions := [6]Vertex{}
	x := rect.x
	y := rect.y
	w := rect.w
	h := rect.h

	tmp: [2]f32

	// first triangle
	tmp = screen2world(x, y)
	positions[0] = Vertex{tmp.x, tmp.y, 0.0, 1.0}
	tmp = screen2world(x, y + h)
	positions[1] = Vertex{tmp.x, tmp.y, 0.0, 1.0}
	tmp = screen2world(x + w, y + h)
	positions[2] = Vertex{tmp.x, tmp.y, 0.0, 1.0}

	// second triangle
	tmp = screen2world(x, y)
	positions[3] = Vertex{tmp.x, tmp.y, 0.0, 1.0}
	tmp = screen2world(x + w, y + h)
	positions[4] = Vertex{tmp.x, tmp.y, 0.0, 1.0}
	tmp = screen2world(x + w, y)
	positions[5] = Vertex{tmp.x, tmp.y, 0.0, 1.0}

	return positions
}

point2vertex :: proc(x: f32, y: f32) -> Vertex {
	tmp := screen2world(x, y)
	return {tmp.x, tmp.y, 0, 1}
}

points2vertices :: proc(points: [][2]f32) -> []Vertex {
	vertices: [dynamic]Vertex

	for point in points {
		append(&vertices, point2vertex(point.x, point.y))
	}

	return vertices[:]
}

shrink :: proc(rect: Rect, rect_offset: RectOffset) -> Rect {
	return Rect {
		rect.x + rect_offset.left,
		rect.y + rect_offset.bottom,
		rect.w - rect_offset.left - rect_offset.right,
		rect.h - rect_offset.bottom - rect_offset.top,
	}
}
