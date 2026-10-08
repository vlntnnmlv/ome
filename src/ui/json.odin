package omeui

import "core:encoding/json"
import "core:log"
import "core:mem"

import "ome:assets"
import "ome:core"

panel_description_from_json :: proc(
	library: ^assets.Library,
	data: []byte,
	allocator: mem.Allocator,
) -> (
	PanelDescription,
	bool,
) {
	value, err := json.parse(data, allocator = allocator)
	if err != .None {
		log.errorf("ui/json: parse error: %v", err)
		return {}, false
	}

	obj, is_object := value.(json.Object)
	if !is_object {
		log.error("ui/json: root must be an object")
		return {}, false
	}

	return panel_description_from_object(library, obj, allocator)
}

@(private)
panel_description_from_object :: proc(
	library: ^assets.Library,
	obj: json.Object,
	allocator: mem.Allocator,
) -> (
	description: PanelDescription,
	ok: bool,
) {
	name, _ := json_string(obj, "name", "unnamed")

	// r: [4]f32
	// if !json_numbers(obj, "rect", r[:]) {
	// 	log.warnf("ui/json: panel '%s' has no valid rect", name)
	// 	return {}, false
	// }

	layout: Layout = {}
	if layout_object, has_layout := obj["layout"].(json.Object); has_layout {
		layout = layout_from_object(layout_object, name)
	}

	spec, spec_ok := spec_from_object(library, obj)
	if !spec_ok {
		return {}, false
	}

	description = PanelDescription {
		name     = name,
		spec     = spec,
		layout   = layout,
		children = make([dynamic]PanelDescription, allocator),
		bindings = make([dynamic]Binding, allocator),
	}

	if children, has_children := obj["children"].(json.Array); has_children {
		for child_value in children {
			child_obj, is_object := child_value.(json.Object)
			if !is_object {
				log.warnf("ui/json: child of '%s' is not an object", name)
				continue
			}

			child, child_ok := panel_description_from_object(library, child_obj, allocator)
			if child_ok {
				append(&description.children, child)
			}
		}
	}

	if bind_obj, has_bind := obj["bind"].(json.Object); has_bind {
		for target_name, path_value in bind_obj {
			path, is_string := path_value.(json.String)
			if !is_string {
				log.warnf("ui/json: '%s' bind.%s must be a string", name, target_name)
				continue
			}

			target: BindTarget
			switch target_name {
			case "text":
				target = .Text
			case "color":
				target = .Color
			case:
				log.warnf("ui/json: '%s' unknown bind target '%s'", name, target_name)
				continue
			}

			append(&description.bindings, Binding{target = target, path = string(path)})
		}
	}

	return description, true
}

@(private)
layout_from_object :: proc(obj: json.Object, name: string) -> Layout {
	layout := Layout{}

	width := json_sizing_from_object(obj, "width", name)
	height := json_sizing_from_object(obj, "height", name)

	min_s: [2]f32
	_ = json_numbers(obj, "min", min_s[:])

	max_s: [2]f32
	_ = json_numbers(obj, "max", max_s[:])

	align := json_align(obj, "align", name)

	flow_string, has_flow := json_string(obj, "flow")
	flow: Flow
	if has_flow {
		switch flow_string {
		case "row":
			flow = .Horizontal
		case "column":
			flow = .Vertical
		case "overlay":
			flow = .Overlay
		}
	}

	content_align_string, has_content_align := json_string(obj, "content_align")
	content_align := Align.Start

	if has_content_align {
		switch content_align_string {
		case "center":
			content_align = .Center
		case "end":
			content_align = .End
		}
	}

	padding: [4]f32
	_ = json_numbers(obj, "padding", padding[:])

	margin: [4]f32
	_ = json_numbers(obj, "margin", margin[:])

	spacing: f32 = json_number(obj, "spacing")

	layout.size = {
		.X = width,
		.Y = height,
	}
	layout.min = {
		.X = min_s.x,
		.Y = min_s.y,
	}
	layout.max = {
		.X = max_s.x,
		.Y = max_s.y,
	}
	layout.align = align
	layout.flow = flow
	layout.padding = core.RectOffset{padding[0], padding[1], padding[2], padding[3]}
	layout.margin = core.RectOffset{margin[0], margin[1], margin[2], margin[3]}
	layout.spacing = spacing
	layout.content_align = content_align

	return layout
}

@(private)
json_sizing_from_object :: proc(obj: json.Object, key, name: string) -> Sizing {
	value, found := obj[key]
	if !found {
		return Fit{}
	}

	#partial switch sizing in value {
	case json.Float:
		return Fixed(f32(sizing))
	case json.Integer:
		return Fixed(f32(sizing))
	case json.String:
		switch sizing {
		case "fit":
			return Fit{}
		case "fill":
			return Fill(1)
		}
	case json.Object:
		if w, ok := sizing["fill"].(json.Float); ok {
			return Fill(f32(w))
		}
	}

	log.warnf("ui/json: panel '%s': invalid '%s', using fit", name, key)
	return Fit{}
}

@(private)
spec_from_object :: proc(library: ^assets.Library, obj: json.Object) -> (Spec, bool) {
	kind, _ := json_string(obj, "kind", "panel")

	color := core.Color{255, 255, 255, 255}
	c: [4]f32
	if json_numbers(obj, "color", c[:]) {
		color = core.color_clamp(c)
	}

	switch kind {
	case "panel":
		return PanelSpec{color = color}, true

	case "image":
		atlas_name, has_atlas := json_string(obj, "atlas")
		sprite_name, has_sprite := json_string(obj, "sprite")
		if !has_atlas || !has_sprite {
			log.warn("ui/json: image panel needs 'atlas' and 'sprite'")
			return nil, false
		}

		atlas_handle, found := assets.library_find_atlas(library, atlas_name)
		if !found {
			log.warnf("ui/json: unknown atlas '%s'", atlas_name)
			return nil, false
		}

		offset: core.RectOffset
		slice: [4]f32
		if json_numbers(obj, "slice", slice[:]) {
			offset = core.RectOffset{slice[0], slice[1], slice[2], slice[3]}
		}

		flip: core.Flip = {}
		flip_value, is_flip := json_string(obj, "flip", ""); if is_flip {
			if flip_value == "x" {
				flip = core.Flip{.X}
			}
			if flip_value == "y" {
				flip = core.Flip{.Y}
			}
			if flip_value == "xy" {
				flip = core.Flip{.X, .Y}
			}
		}

		return ImageSpec {
				panel = PanelSpec{color = color},
				atlas_handle = atlas_handle,
				sprite_name = sprite_name,
				slice_offset = offset,
				flip = flip,
			},
			true

	case "text":
		text, has_text := json_string(obj, "text")
		font_name, has_font := json_string(obj, "font")
		if !has_text || !has_font {
			log.warn("ui/json: text panel needs 'text' and 'font'")
			return nil, false
		}

		font_handle, found := assets.library_find_font(library, font_name)
		if !found {
			log.warnf("ui/json: unknown font '%s'", font_name)
			return nil, false
		}

		size := json_number(obj, "size", 32)

		return TextSpec {
				panel = PanelSpec{color = color},
				text = text,
				font_handle = font_handle,
				font_size = u32(size),
			},
			true
	case "button":
		action, has_action := json_string(obj, "on_click")
		if !has_action {
			log.warn("ui/json: button panel needs 'on_click'")
			return nil, false
		}
		return ButtonSpec{panel = PanelSpec{color = color}, action = action}, true
	}

	log.warnf("ui/json: unknown kind '%s'", kind)
	return nil, false
}

@(private = "file")
json_string :: proc(obj: json.Object, key: string, fallback := "") -> (string, bool) {
	str, ok := obj[key].(json.String)
	if ok {
		return string(str), true
	}
	return fallback, false
}

json_align :: proc(obj: json.Object, key, name: string) -> (align: [core.Axis]Align) {
	#partial switch value in obj[key] {
	case json.String:
		a := json_align_value(string(value), key, name)
		align = {
			.X = a,
			.Y = a,
		}
	case json.Array:
		if len(value) != 2 {
			log.warnf("ui/json: panel '%s': '%s' array needs 2 values", name, key)
			return
		}
		for axis in core.Axis {
			if s, is_string := value[int(axis)].(json.String); is_string {
				align[axis] = json_align_value(string(s), key, name)
			}
		}
	}
	return
}

json_align_value :: proc(s, key, name: string) -> Align {
	switch s {
	case "start":
		return .Start
	case "center":
		return .Center
	case "end":
		return .End
	}
	log.warnf("ui/json: panel '%s': unknown %s '%s', using start", name, key, s)
	return .Start
}

@(private = "file")
json_number :: proc(obj: json.Object, key: string, fallback: f32 = 0) -> f32 {
	n, ok := obj[key].(json.Float)
	if ok {
		return f32(n)
	}
	return fallback
}

@(private = "file")
json_numbers :: proc(obj: json.Object, key: string, out: []f32) -> bool {
	arr, ok := obj[key].(json.Array)
	if !ok || len(arr) < len(out) {
		return false
	}
	for &o, i in out {
		n, is_number := arr[i].(json.Float)
		if !is_number {
			return false
		}
		o = f32(n)
	}
	return true
}
