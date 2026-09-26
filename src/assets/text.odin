package omeassets

import "core:math"
import "core:unicode/utf8"

import STBTT "vendor:stb/truetype"

import "ome:core"
import "ome:gpu"

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

font_text_layout :: proc(
	font: ^Font,
	text: string,
	font_size: u32,
	origin: [2]f32,
) -> (
	[]gpu.Position,
	[]gpu.UV,
) {
	origin := origin

	cap := len(text) * gpu.VERTICES_PER_QUAD
	total_positions := make([dynamic]gpu.Position, 0, cap, context.temp_allocator)
	total_uvs := make([dynamic]gpu.UV, 0, cap, context.temp_allocator)

	it := StringPrintableIterator{text, 0}
	for char in printable_iter(&it) {
		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&font.char_data[font_size][0],
			font.bitmap_size,
			font.bitmap_size,
			i32(char) - FIRST_CHAR,
			&origin.x,
			&origin.y,
			&quad,
			true,
		)

		char_rect := core.Rect{quad.x0, quad.y0, quad.x1 - quad.x0, quad.y1 - quad.y0}
		vertices := gpu.rect_to_vertices_positions(char_rect)

		uvs := [gpu.VERTICES_PER_QUAD]gpu.UV {
			{quad.s0, quad.t0},
			{quad.s0, quad.t1},
			{quad.s1, quad.t1},
			{quad.s0, quad.t0},
			{quad.s1, quad.t1},
			{quad.s1, quad.t0},
		}

		append(&total_positions, ..vertices[:])
		append(&total_uvs, ..uvs[:])
	}

	return total_positions[:], total_uvs[:]
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
