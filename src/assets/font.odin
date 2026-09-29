package omeassets

import "core:log"
import "core:os"
import "core:slice"

import STBRP "vendor:stb/rect_pack"
import STBTT "vendor:stb/truetype"

import "ome:core"
import "ome:gpu"
import "ome:handle_map"

INITIAL_BITMAP_SIZE :: 1024
REFERENCE_FONT_SIZE :: 32

FIRST_CHAR :: 32
CHAR_COUNT :: 95

FontHandle :: distinct handle_map.Handle

Font :: struct {
	handle:         FontHandle,
	path:           string,
	data:           []u8,
	info:           STBTT.fontinfo,
	pack_context:   STBTT.pack_context,
	bitmap_size:    i32,
	bitmap:         []u8,
	sizes:          [dynamic]u32,
	pending:        [dynamic]u32,
	unpackable:     [dynamic]u32,
	char_data:      map[u32][]STBTT.packedchar,
	texture_handle: gpu.TextureHandle,
	dirty_rect:     core.Rect,
}

font_ensure_size :: proc(font: ^Font, size: u32) {
	if slice.contains(font.sizes[:], size) {
		return
	}
	if slice.contains(font.pending[:], size) {
		return
	}
	if slice.contains(font.unpackable[:], size) {
		return
	}
	append(&font.pending, size)
}

font_nearest_size :: proc(font: ^Font, size: u32) -> u32 {
	best_fit := font.sizes[0]
	for s in font.sizes {
		if abs(int(s) - int(size)) < abs(int(best_fit) - int(size)) {
			best_fit = s
		}
	}
	return best_fit
}

@(private)
font_load :: proc(font: ^Font, path: string, sizes: []u32 = {}) -> Error {
	font.path = path
	font.bitmap_size = INITIAL_BITMAP_SIZE

	data, err := os.read_entire_file_from_path(font.path, context.allocator)
	if err != nil {
		log.errorf("assets/font: failed to load font at '%s'", path)
		return .File
	}

	font.data = data

	if !STBTT.InitFont(&font.info, raw_data(font.data), 0) {
		log.errorf("assets/font: failed to init font at '%s'", path)
		return .Init
	}

	font.bitmap = make([]u8, font.bitmap_size * font.bitmap_size)
	font.char_data = make(map[u32][]STBTT.packedchar)
	font.sizes = make([dynamic]u32)
	font.pending = make([dynamic]u32)
	font.unpackable = make([dynamic]u32)

	if STBTT.PackBegin(
		   &font.pack_context,
		   raw_data(font.bitmap),
		   font.bitmap_size,
		   font.bitmap_size,
		   0,
		   1,
		   nil,
	   ) ==
	   false {
		log.errorf("assets/font: failed to pack font at '%s'", path)
		return .Pack
	}

	STBTT.PackSetOversampling(&font.pack_context, 2, 2)

	font_pack_size(font, REFERENCE_FONT_SIZE) or_return

	for size in sizes {
		if size == REFERENCE_FONT_SIZE {
			continue
		}

		font_pack_size(font, size) or_return
	}

	return .None
}

@(private)
font_pack_size :: proc(font: ^Font, size: u32) -> Error {
	chars := make([]STBTT.packedchar, CHAR_COUNT)

	range := STBTT.pack_range {
		font_size                        = f32(size),
		first_unicode_codepoint_in_range = FIRST_CHAR,
		num_chars                        = CHAR_COUNT,
		chardata_for_range               = raw_data(chars),
	}

	rects := make([]STBRP.Rect, CHAR_COUNT, context.temp_allocator)

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
			return .Pack
		}
		font.dirty_rect = core.rect_union(
			font.dirty_rect,
			core.Rect{f32(r.x), f32(r.y), f32(r.w), f32(r.h)},
		)
	}

	STBTT.PackFontRangesRenderIntoRects(&font.pack_context, &font.info, &range, 1, raw_data(rects))

	font.char_data[size] = chars
	append(&font.sizes, size)
	slice.sort(font.sizes[:])

	return .None
}

@(private)
font_flush :: proc(font: ^Font, bind_table: ^gpu.BindTable) {
	for size in font.pending {
		if err := font_pack_size(font, size); err != .None {
			log.warnf(
				"assets/font: bitmap full, size %d not packed for '%s', using nearest size",
				size,
				font.path,
			)
			append(&font.unpackable, size)
		}
	}
	clear(&font.pending)

	if font.dirty_rect.w <= 0 || font.dirty_rect.h <= 0 {
		return
	}

	if !handle_map.valid(bind_table.textures, font.texture_handle) {
		texture_handle, err := gpu.texture_create_from_data(
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
			.R8_Unorm,
		)
		if err != .None {
			return
		}
		font.texture_handle = texture_handle
	} else {
		gpu.texture_write_region(
			bind_table,
			font.texture_handle,
			font.dirty_rect,
			raw_data(font.bitmap),
			int(font.bitmap_size),
			.R8_Unorm,
		)
	}

	font.dirty_rect = {}
}

@(private)
font_destroy :: proc(font: ^Font) {
	for _, &value in font.char_data {
		delete(value)
	}

	STBTT.PackEnd(&font.pack_context)
	delete(font.char_data)
	delete(font.bitmap)
	delete(font.sizes)
	delete(font.data)
	delete(font.pending)
	delete(font.unpackable)
}
