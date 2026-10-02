package omeui

import "ome:core"
Sizing :: union {
	Fixed,
	Fit,
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

Axis :: enum {
	Vertical,
	Horizontal,
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

measure :: proc() {

}
