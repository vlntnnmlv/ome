package omeui

import "../core"

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
	using panel:    PanelSpec,
	texture_handle: core.TextureHandle,
	slice_offset:   core.RectOffset,
}

TextSpec :: struct {
	using panel: PanelSpec,
	text:        string,
	font_size:   u32,
}
