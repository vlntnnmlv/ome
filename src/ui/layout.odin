package omeui

import "ome:core"

Sizing :: union #no_nil {
	Fit,
	Fixed,
	Fill,
	Percent,
}

Fixed :: distinct f32 // size in pixels
Fit :: struct {}
Fill :: distinct f32 // ratio of fill distribution
Percent :: distinct f32 // size in percentage of the parent container

Align :: enum {
	Start,
	Center,
	End,
}

Flow :: enum {
	Horizontal,
	Vertical,
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
