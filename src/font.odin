package ome

import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"
import STBTT "vendor:stb/truetype"

INITIAL_BITMAP_SIZE :: 1024

CharAtStart :: 32
CharAmount :: 95

FontError :: enum {
	None = 0,
	File_Error,
	Packing_Error,
}

Font :: struct {
	path:        string,
	bitmap_size: i32,
	bitmap:      []u8,
	sizes:       [dynamic]u32,
	char_data:   map[u32][]STBTT.packedchar,
	texture:     ^MTL.Texture,
	sampler:     ^MTL.SamplerState,
}

REFERENCE_FONT_SIZE :: 32

assets_load_font :: proc(renderer: ^Renderer, path: string, sizes: []u32 = {}) {
	renderer.font.path = path
	renderer.font.bitmap_size = INITIAL_BITMAP_SIZE

	renderer.font.sizes = make([dynamic]u32)

	for size in sizes do append(&renderer.font.sizes, size)

	if len(renderer.font.sizes) == 0 ||
	   !slice.contains(renderer.font.sizes[:], REFERENCE_FONT_SIZE) {
		append(&renderer.font.sizes, REFERENCE_FONT_SIZE)
	}

	assets_pack_font(renderer)
}

assets_pack_font :: proc(renderer: ^Renderer) {
	for {
		err := assets_pack_font_internal(renderer)
		if err == .Packing_Error do renderer.font.bitmap_size *= 2
		else do break
	}
}

assets_validate_font_size :: proc(renderer: ^Renderer, size: u32) {
	if !slice.contains(renderer.font.sizes[:], size) {
		append(&renderer.font.sizes, size)
		assets_pack_font(renderer)
	}
}

assets_pack_font_internal :: proc(renderer: ^Renderer) -> FontError {
	font_data, err := os.read_entire_file_from_path(renderer.font.path, context.temp_allocator)
	defer delete(font_data, context.temp_allocator)
	if err != nil do return .File_Error

	// clean exisiting font data
	if renderer.font.texture != nil {
		renderer.font.texture->release()
		renderer.font.texture = nil
	}
	if renderer.font.sampler != nil {
		renderer.font.sampler->release()
		renderer.font.sampler = nil
	}
	if renderer.font.bitmap != nil do delete(renderer.font.bitmap)
	if renderer.font.char_data != nil {
		for _, &char_data in renderer.font.char_data do delete(char_data)
		delete(renderer.font.char_data)
	}

	// create empty data
	renderer.font.bitmap, err = make([]u8, renderer.font.bitmap_size * renderer.font.bitmap_size)
	renderer.font.char_data = make(map[u32][]STBTT.packedchar)
	for size in renderer.font.sizes {
		renderer.font.char_data[size] = make([]STBTT.packedchar, CharAmount)
	}

	// pack font
	pack_context := new(STBTT.pack_context, context.temp_allocator)
	STBTT.PackBegin(
		pack_context,
		&renderer.font.bitmap[0],
		renderer.font.bitmap_size,
		renderer.font.bitmap_size,
		0,
		1,
		nil,
	)
	STBTT.PackSetOversampling(pack_context, 2, 2)
	for size, i in renderer.font.sizes {
		if ok := STBTT.PackFontRange(
			pack_context,
			&font_data[0],
			0,
			cast(f32)size,
			CharAtStart,
			CharAmount,
			&renderer.font.char_data[renderer.font.sizes[i]][0],
		); ok != 1 {
			STBTT.PackEnd(pack_context)
			return .Packing_Error
		}
	}
	STBTT.PackEnd(pack_context)

	// bake to bitmap to metal texture
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.R8Unorm,
		cast(NS.UInteger)renderer.font.bitmap_size,
		cast(NS.UInteger)renderer.font.bitmap_size,
		false,
	)
	desc->setStorageMode(.Shared)
	renderer.font.texture = renderer.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {
			cast(NS.Integer)renderer.font.bitmap_size,
			cast(NS.Integer)renderer.font.bitmap_size,
			1,
		},
	}
	renderer.font.texture->replaceRegion(
		region,
		0,
		raw_data(renderer.font.bitmap),
		cast(NS.UInteger)renderer.font.bitmap_size,
	)
	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Nearest)
	samp_desc->setMagFilter(.Nearest)
	samp_desc->setSAddressMode(.ClampToZero)
	samp_desc->setTAddressMode(.ClampToZero)
	renderer.font.sampler = renderer.device->newSamplerState(samp_desc)

	// DEBUG: save bitmap to .png
	filename := strings.concatenate(
		{
			"debug/",
			strings.split(filepath.base(renderer.font.path), ".", context.temp_allocator)[0],
			".png",
		},
		context.temp_allocator,
	)

	STBI.write_png(
		strings.clone_to_cstring(filename, context.temp_allocator),
		renderer.font.bitmap_size,
		renderer.font.bitmap_size,
		1,
		raw_data(renderer.font.bitmap),
		pack_context.stride_in_bytes,
	)

	return .None
}

assets_delete_font :: proc(font: ^Font) {
	for _, &value in font.char_data {
		delete(value)
	}

	delete(font.char_data)
	delete(font.bitmap)
	delete(font.sizes)
}
