package ome

import STBTT "vendor:stb/truetype"

text_measure :: proc(app: ^App, text: string, font_size: f32) -> [2]f32 {
	assets_validate_font_size(app, font_size)

	x, y, max_x: f32 = 0, 0, 0
	for ch in text {
		if ch < CharAtStart || ch > CharAtStart + CharAmount do continue

		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font.char_data[font_size][0],
			app.font.bitmap_size,
			app.font.bitmap_size,
			cast(i32)ch - 32,
			&x,
			&y,
			&quad,
			true,
		)
		max_x = max(x, max_x)
	}

	return {max_x, font_size}
}

text_fit :: proc(app: ^App, text: string, font_size: f32, rect: Rect) -> f32 {
	size := text_measure(app, text, font_size)
	scale_x := rect.w / size.x
	scale_y := rect.h / size.y
	scale := min(scale_x, scale_y)
	return font_size * min(scale, 1)
}
