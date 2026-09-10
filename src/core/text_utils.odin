package omecore

import "core:math"
import "core:unicode/utf8"

import STBTT "vendor:stb/truetype"

StringPrintableIterator :: struct {
	s: string,
	i: int,
}

iterate_printable :: proc(it: ^StringPrintableIterator) -> (rune, int, bool) {
	for it.i < len(it.s) {
		ch, width := utf8.decode_rune(it.s[it.i:])
		i := it.i
		it.i += width

		if ch < CharAtStart || ch >= CharAtStart + CharAmount || width > 1 {
			continue
		}

		return ch, i, true
	}

	return 0, len(it.s), false
}

text_measure :: proc(font: ^Font, text: string, font_size: u32) -> [2]f32 {
	x, y, max_x: f32 = 0, 0, 0
	it := StringPrintableIterator{text, 0}
	for ch in iterate_printable(&it) {
		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&font.char_data[REFERENCE_FONT_SIZE][0],
			font.bitmap_size,
			font.bitmap_size,
			cast(i32)ch - 32,
			&x,
			&y,
			&quad,
			true,
		)
		max_x = max(x, max_x)
	}

	scale := cast(f32)font_size / cast(f32)REFERENCE_FONT_SIZE

	return {max_x * scale, cast(f32)font_size}
}

text_fit :: proc(font: ^Font, text: string, font_size: u32, rect: Rect) -> u32 {
	size := text_measure(font, text, font_size)
	scale_x := rect.w / size.x
	scale_y := rect.h / size.y
	scale := min(scale_x, scale_y)
	return cast(u32)math.round(cast(f32)font_size * min(scale, 1))
}
