package omeassets

import "core:math"
import "core:unicode/utf8"

import STBTT "vendor:stb/truetype"

import "ome:core"

StringPrintableIterator :: struct {
	s: string,
	i: int,
}

@(private)
printable_iter :: proc(it: ^StringPrintableIterator) -> (rune, int, bool) {
	for it.i < len(it.s) {
		ch, width := utf8.decode_rune(it.s[it.i:])
		i := it.i
		it.i += width

		if ch < FIRST_CHAR || ch >= FIRST_CHAR + CHAR_COUNT || width > 1 {
			continue
		}

		return ch, i, true
	}

	return 0, len(it.s), false
}

Glyph :: struct {
	rect:    core.Rect,
	uv_rect: core.Rect,
}

GlyphIterator :: struct {
	font:   ^Font,
	chars:  []STBTT.packedchar,
	text:   StringPrintableIterator,
	origin: [2]f32,
}

font_make_glyphs_iterator :: proc(
	font: ^Font,
	text: string,
	font_size: u32,
	origin: [2]f32,
) -> GlyphIterator {
	return GlyphIterator {
		font = font,
		chars = font.char_data[font_size],
		text = StringPrintableIterator{text, 0},
		origin = origin,
	}
}

font_iter_glyphs :: proc(it: ^GlyphIterator) -> (Glyph, bool) {
	char, _, ok := printable_iter(&it.text)
	if !ok {
		return {}, false
	}

	quad: STBTT.aligned_quad
	STBTT.GetPackedQuad(
		&it.chars[0],
		it.font.bitmap_size,
		it.font.bitmap_size,
		i32(char) - FIRST_CHAR,
		&it.origin.x,
		&it.origin.y,
		&quad,
		true,
	)

	return Glyph {
			rect = core.Rect{quad.x0, quad.y0, quad.x1 - quad.x0, quad.y1 - quad.y0},
			uv_rect = core.Rect{quad.s0, quad.t0, quad.s1 - quad.s0, quad.t1 - quad.t0},
		},
		true
}

font_text_measure :: proc(font: ^Font, text: string, font_size: u32) -> [2]f32 {
	x, y, max_x: f32 = 0, 0, 0
	it := StringPrintableIterator{text, 0}
	for ch in printable_iter(&it) {
		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&font.char_data[REFERENCE_FONT_SIZE][0],
			font.bitmap_size,
			font.bitmap_size,
			i32(ch) - FIRST_CHAR,
			&x,
			&y,
			&quad,
			true,
		)
		max_x = max(x, max_x)
	}

	scale := f32(font_size) / f32(REFERENCE_FONT_SIZE)

	return {max_x * scale, f32(font_size)}
}

font_text_fit :: proc(font: ^Font, text: string, font_size: u32, rect: core.Rect) -> u32 {
	size := font_text_measure(font, text, font_size)
	scale_x := rect.w / size.x
	scale_y := rect.h / size.y
	scale := min(scale_x, scale_y)
	return u32(math.round(f32(font_size) * min(scale, 1)))
}
