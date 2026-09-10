package omecore

import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"
import STBTT "vendor:stb/truetype"

INITIAL_BITMAP_SIZE :: 1024
REFERENCE_FONT_SIZE :: 32

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
	// texture:     TextureHandle,
	sampler:     ^MTL.SamplerState,
}

FontManager :: struct {
	fonts: [dynamic]^Font,
}

FontHandle :: distinct u32

font_manager_create :: proc() -> ^FontManager {
	font_manager := new(FontManager)
	font_manager.fonts = make([dynamic]^Font)

	return font_manager
}

font_load :: proc(font: ^Font, device: ^MTL.Device, path: string, sizes: []u32 = {}) {
	font.path = path
	font.bitmap_size = INITIAL_BITMAP_SIZE

	font.sizes = make([dynamic]u32)

	for size in sizes do append(&font.sizes, size)

	if len(font.sizes) == 0 || !slice.contains(font.sizes[:], REFERENCE_FONT_SIZE) {
		append(&font.sizes, REFERENCE_FONT_SIZE)
	}

	font_pack(font, device)
}

font_pack :: proc(font: ^Font, device: ^MTL.Device) {
	for {
		err := font_pack_internal(font, device)
		if err == .Packing_Error do font.bitmap_size *= 2
		else do break
	}
}

font_validate_size :: proc(font: ^Font, device: ^MTL.Device, size: u32) {
	if !slice.contains(font.sizes[:], size) {
		append(&font.sizes, size)
		font_pack(font, device)
	}
}

font_pack_internal :: proc(font: ^Font, device: ^MTL.Device) -> FontError {
	font_data, err := os.read_entire_file_from_path(font.path, context.temp_allocator)
	defer delete(font_data, context.temp_allocator)
	if err != nil do return .File_Error

	// clean exisiting font data
	// if font.texture != nil {
	// 	font.texture->release()
	// 	font.texture = nil
	// }
	if font.sampler != nil {
		font.sampler->release()
		font.sampler = nil
	}
	if font.bitmap != nil do delete(font.bitmap)
	if font.char_data != nil {
		for _, &char_data in font.char_data do delete(char_data)
		delete(font.char_data)
	}

	// create empty data
	font.bitmap, err = make([]u8, font.bitmap_size * font.bitmap_size)
	font.char_data = make(map[u32][]STBTT.packedchar)
	for size in font.sizes {
		font.char_data[size] = make([]STBTT.packedchar, CharAmount)
	}

	// pack font
	pack_context := new(STBTT.pack_context, context.temp_allocator)
	STBTT.PackBegin(pack_context, &font.bitmap[0], font.bitmap_size, font.bitmap_size, 0, 1, nil)
	STBTT.PackSetOversampling(pack_context, 2, 2)
	for size, i in font.sizes {
		if ok := STBTT.PackFontRange(
			pack_context,
			&font_data[0],
			0,
			cast(f32)size,
			CharAtStart,
			CharAmount,
			&font.char_data[font.sizes[i]][0],
		); ok != 1 {
			STBTT.PackEnd(pack_context)
			return .Packing_Error
		}
	}
	STBTT.PackEnd(pack_context)

	// bake to bitmap to metal texture
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.R8Unorm,
		cast(NS.UInteger)font.bitmap_size,
		cast(NS.UInteger)font.bitmap_size,
		false,
	)
	desc->setStorageMode(.Shared)
	font.texture = device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)font.bitmap_size, cast(NS.Integer)font.bitmap_size, 1},
	}
	font.texture->replaceRegion(
		region,
		0,
		raw_data(font.bitmap),
		cast(NS.UInteger)font.bitmap_size,
	)
	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Nearest)
	samp_desc->setMagFilter(.Nearest)
	samp_desc->setSAddressMode(.ClampToZero)
	samp_desc->setTAddressMode(.ClampToZero)
	font.sampler = device->newSamplerState(samp_desc)

	// DEBUG: save bitmap to .png
	filename := strings.concatenate(
		{
			"debug/",
			strings.split(filepath.base(font.path), ".", context.temp_allocator)[0],
			".png",
		},
		context.temp_allocator,
	)

	STBI.write_png(
		strings.clone_to_cstring(filename, context.temp_allocator),
		font.bitmap_size,
		font.bitmap_size,
		1,
		raw_data(font.bitmap),
		pack_context.stride_in_bytes,
	)

	return .None
}

font_delete :: proc(font: ^Font) {
	for _, &value in font.char_data {
		delete(value)
	}

	delete(font.char_data)
	delete(font.bitmap)
	delete(font.sizes)
	font.texture->release()
	font.sampler->release()
}
