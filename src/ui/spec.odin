package omeui

import "ome:assets"
import "ome:core"

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
	atlas_handle: assets.AtlasHandle,
	sprite_name:  string,
	slice_offset: core.RectOffset,
}

TextSpec :: struct {
	using panel: PanelSpec,
	text:        string,
	font_handle: assets.FontHandle,
	font_size:   u32,
}
