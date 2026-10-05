package omeui

import "ome:core"

Sizing :: union #no_nil {
	Fit,
	Fixed,
	Fill,
	Percent,
}

Fixed :: distinct f32
Fit :: struct {}
Fill :: distinct f32
Percent :: distinct f32

Align :: enum {
	Start,
	Center,
	End,
}

Flow :: enum {
	Row,
	Column,
	Overlay,
}

Layout :: struct {
	// child
	size:          [core.Axis]Sizing,
	min, max:      [core.Axis]f32,
	align:         [core.Axis]Align,
	margin:        core.RectOffset,
	// container
	flow:          Flow,
	padding:       core.RectOffset,
	spacing:       f32,
	content_align: Align,
}
