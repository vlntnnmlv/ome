package omeresources

import "core:os"
import "core:slice"

import STBRP "vendor:stb/rect_pack"
import STBTT "vendor:stb/truetype"

import "ome:core"
import "ome:core/gpu"
import "ome:core/handle_map"

INITIAL_BITMAP_SIZE :: 1024
REFERENCE_FONT_SIZE :: 32

CharAtStart :: 32
CharAmount :: 95

FontError :: enum {
	None = 0,
	File_Error,
	Init_Error,
	Packing_Error,
}

FontHandle :: distinct handle_map.Handle

Font :: struct {
	handle:       FontHandle,
	path:         string,
	data:         []u8,
	info:         STBTT.fontinfo,
	pack_context: STBTT.pack_context,
	bitmap_size:  i32,
	bitmap:       []u8,
	sizes:        [dynamic]u32,
	pending:      [dynamic]u32,
	char_data:    map[u32][]STBTT.packedchar,
	texture:      gpu.TextureHandle,
	dirty:        bool,
}

font_load :: proc(font: ^Font, path: string, sizes: []u32 = {}) -> FontError {
	font.path = path
	font.bitmap_size = INITIAL_BITMAP_SIZE

	data, err := os.read_entire_file_from_path(font.path, context.allocator)
	if err != nil do return .File_Error
	font.data = data

	if !STBTT.InitFont(&font.info, raw_data(font.data), 0) do return .Init_Error

	font.bitmap = make([]u8, font.bitmap_size * font.bitmap_size)
	font.char_data = make(map[u32][]STBTT.packedchar)
	font.sizes = make([dynamic]u32)
	font.pending = make([dynamic]u32)

	if STBTT.PackBegin(
		   &font.pack_context,
		   raw_data(font.bitmap),
		   font.bitmap_size,
		   font.bitmap_size,
		   0,
		   1,
		   nil,
	   ) ==
	   0 {
		return .Packing_Error
	}

	STBTT.PackSetOversampling(&font.pack_context, 2, 2)

	font_pack_size(font, REFERENCE_FONT_SIZE) or_return

	for size in sizes {
		if size == REFERENCE_FONT_SIZE do continue
		font_pack_size(font, size) or_return
	}

	return .None
}

font_ensure_size :: proc(font: ^Font, size: u32) {
	if slice.contains(font.sizes[:], size) do return
	if slice.contains(font.pending[:], size) do return
	append(&font.pending, size)
}

font_nearest_size :: proc(font: ^Font, size: u32) -> u32 {
	best_fit := font.sizes[0]
	for s in font.sizes {
		if abs(int(s) - int(size)) < abs(int(best_fit) - int(size)) do best_fit = s
	}
	return best_fit
}

font_pack_size :: proc(font: ^Font, size: u32) -> FontError {
	chars := make([]STBTT.packedchar, CharAmount)

	range := STBTT.pack_range {
		font_size                        = f32(size),
		first_unicode_codepoint_in_range = CharAtStart,
		num_chars                        = CharAmount,
		chardata_for_range               = raw_data(chars),
	}

	rects := make([]STBRP.Rect, CharAmount, context.temp_allocator)

	n := STBTT.PackFontRangesGatherRects(
		&font.pack_context,
		&font.info,
		&range,
		1,
		raw_data(rects),
	)
	STBTT.PackFontRangesPackRects(&font.pack_context, raw_data(rects), n)

	for r in rects[:n] {
		if !r.was_packed {
			delete(chars)
			return .Packing_Error
		}
	}

	STBTT.PackFontRangesRenderIntoRects(&font.pack_context, &font.info, &range, 1, raw_data(rects))

	font.char_data[size] = chars
	append(&font.sizes, size)
	slice.sort(font.sizes[:])
	font.dirty = true

	return .None
}

font_flush :: proc(font: ^Font, bind_table: ^gpu.BindTable) {
	for size in font.pending do font_pack_size(font, size)
	clear(&font.pending)

	if !font.dirty do return

	if !handle_map.valid(bind_table.textures, font.texture) {
		font.texture = gpu.texture_create_from_data(
			bind_table,
			gpu.TextureData {
				name = "font",
				pixels = raw_data(font.bitmap),
				width = font.bitmap_size,
				height = font.bitmap_size,
				channels = 1,
				in_atlas = false,
				atlas_rect = core.Rect{},
			},
			gpu.TextureFormat{.R8Unorm, 1},
		)
	} else {
		gpu.texture_write(bind_table, font.texture, raw_data(font.bitmap), {.R8Unorm, 1})
	}

	font.dirty = false
}

font_delete :: proc(font: ^Font) {
	for _, &value in font.char_data {
		delete(value)
	}

	STBTT.PackEnd(&font.pack_context)
	delete(font.char_data)
	delete(font.bitmap)
	delete(font.sizes)
	delete(font.data)
	delete(font.pending)
}
