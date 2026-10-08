package omeui

import "ome:assets"
import "ome:core"

@(private)
layout_measure_content :: proc(
	scene: ^Scene,
	panel: ^Panel,
) -> (
	size: [core.Axis]f32,
	min_size: [core.Axis]f32,
) {
	#partial switch spec in panel.spec {
	case TextSpec:
		font := assets.library_get_font(scene.library, spec.font_handle)
		if font == nil {
			return
		}
		measured := assets.font_text_measure(font, spec.text, spec.font_size)
		size = {
			.X = measured.x,
			.Y = measured.y,
		}
		return size, size
	case ImageSpec:
		atlas := assets.library_get_atlas(scene.library, spec.atlas_handle)
		if atlas == nil {
			return
		}
		sprite, found := atlas.sprites[spec.sprite_name]
		if !found {
			return
		}
		return {.X = sprite.atlas_rect.w, .Y = sprite.atlas_rect.h}, {}
	}

	return
}
