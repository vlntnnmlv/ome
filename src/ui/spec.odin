package omeui

import "core:mem"
import "core:strings"
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

@(private)
spec_clone :: proc(spec: Spec, allocator: mem.Allocator = context.allocator) -> Spec {
	switch s in spec {
	case PanelSpec:
		return s
	case ImageSpec:
		s_cloned := s
		s_cloned.sprite_name = strings.clone(s.sprite_name, allocator)
		return s_cloned
	case TextSpec:
		s_cloned := s
		s_cloned.text = strings.clone(s.text, allocator)
		return s_cloned
	}
	return spec
}

@(private)
spec_destroy :: proc(spec: Spec, allocator := context.allocator) {
	#partial switch s in spec {
	case ImageSpec:
		delete(s.sprite_name, allocator)
	case TextSpec:
		delete(s.text, allocator)
	}
}
