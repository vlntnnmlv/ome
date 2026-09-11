package omeui

import "ome:core"
import "ome:core/resources"

Spec :: union {
	PanelSpec,
	ImageSpec,
	TextSpec,
}

PanelSpec :: struct {
	color: core.Color,
}

ButtonSpec :: struct {
	using panel: PanelSpec,
	action:      proc(ctx: rawptr),
}

ImageSpec :: struct {
	using panel:  PanelSpec,
	atlas_handle: resources.AtlasHandle,
	sprite_name:  string,
	slice_offset: core.RectOffset,
}

TextSpec :: struct {
	using panel: PanelSpec,
	text:        string,
	font_handle: resources.FontHandle,
	font_size:   u32,
}
