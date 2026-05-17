package ome

import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"
import STBTT "vendor:stb/truetype"

Font :: struct {
	path:          string,
	bitmap_size:   i32,
	bitmap:        []u8,
	sizes:         [dynamic]f32,
	char_data_new: map[f32][]STBTT.packedchar,
	texture:       ^MTL.Texture,
	sampler:       ^MTL.SamplerState,
}

CharAtStart :: 32
CharAmount :: 95

FontError :: enum {
	FILE_ERROR,
	PACKING_ERROR,
}

INITIAL_BITMAP_SIZE :: 1024

asset_pack_font :: proc() {
	for {
		ok, err := assets_load_font_internal()
		if ok || err == .FILE_ERROR do break
		if err == .PACKING_ERROR do app.font.bitmap_size *= 2
	}
}

assets_load_font :: proc(path: string, sizes: []f32) {
	app.font.path = path
	app.font.bitmap_size = INITIAL_BITMAP_SIZE

	for size in sizes do append(&app.font.sizes, size)

	asset_pack_font()
}

asset_update_font_sizes :: proc(size: f32) {
	append(&app.font.sizes, size)
	asset_pack_font()
}

asset_get_or_update_font_size :: proc(size: f32) -> f32 {
	if !slice.contains(app.font.sizes[:], size) do asset_update_font_sizes(size)
	return size
}

assets_load_font_internal :: proc() -> (bool, FontError) {
	font_data, err := os.read_entire_file_from_path(app.font.path, context.allocator)
	defer delete(font_data, context.allocator)
	if err != nil do return false, .FILE_ERROR

	// clean exisiting font data
	if app.font.texture != nil {
		app.font.texture->release()
		app.font.texture = nil
	}
	if app.font.sampler != nil {
		app.font.sampler->release()
		app.font.sampler = nil
	}
	if app.font.bitmap != nil do delete(app.font.bitmap)
	if app.font.char_data_new != nil {
		for _, &char_data in app.font.char_data_new do delete(char_data)
		delete(app.font.char_data_new)
	}

	// create empty data
	app.font.bitmap, err = make([]u8, app.font.bitmap_size * app.font.bitmap_size)
	app.font.char_data_new = make(map[f32][]STBTT.packedchar)
	for size in app.font.sizes {
		app.font.char_data_new[size] = make([]STBTT.packedchar, CharAmount)
	}

	// pack font}
	pack_context := new(STBTT.pack_context, context.temp_allocator)
	STBTT.PackBegin(
		pack_context,
		&app.font.bitmap[0],
		app.font.bitmap_size,
		app.font.bitmap_size,
		0,
		1,
		nil,
	)
	STBTT.PackSetOversampling(pack_context, 2, 2)
	for size, i in app.font.sizes {
		if ok := STBTT.PackFontRange(
			pack_context,
			&font_data[0],
			0,
			size,
			CharAtStart,
			CharAmount,
			&app.font.char_data_new[app.font.sizes[i]][0],
		); ok != 1 {
			STBTT.PackEnd(pack_context)
			return false, .PACKING_ERROR
		}
	}
	STBTT.PackEnd(pack_context)

	// bake to bitmap to metal texture
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.R8Unorm,
		cast(NS.UInteger)app.font.bitmap_size,
		cast(NS.UInteger)app.font.bitmap_size,
		false,
	)
	desc->setStorageMode(.Shared)
	app.font.texture = app.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)app.font.bitmap_size, cast(NS.Integer)app.font.bitmap_size, 1},
	}
	app.font.texture->replaceRegion(
		region,
		0,
		raw_data(app.font.bitmap),
		cast(NS.UInteger)app.font.bitmap_size,
	)
	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Nearest)
	samp_desc->setMagFilter(.Nearest)
	samp_desc->setSAddressMode(.ClampToZero)
	samp_desc->setTAddressMode(.ClampToZero)
	app.font.sampler = app.device->newSamplerState(samp_desc)

	// DEBUG: save bitmap to .png
	filename := strings.concatenate(
		{"debug/", strings.split(filepath.base(app.font.path), ".")[0], ".png"},
	)

	STBI.write_png(
		strings.clone_to_cstring(filename),
		app.font.bitmap_size,
		app.font.bitmap_size,
		1,
		raw_data(app.font.bitmap),
		pack_context.stride_in_bytes,
	)

	return true, nil
}
