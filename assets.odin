package ome

import "core:os"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"
import STBTT "vendor:stb/truetype"

FONT_ATLAS_SIZE :: 1024

FontData :: struct {
	char_data: [96]STBTT.bakedchar,
}

FontDataNew :: struct {
	bitmap:       []u8,
	char_data:    []STBTT.packedchar,
	// atlas:        ^SDL.Texture,
	texture_size: i32,
	line_height:  f32,
}

app_load_font :: proc(window: ^App, ttf_path: string, size: f32) -> bool {
	font_data, err := os.read_entire_file_from_path(ttf_path, context.allocator)
	if err != nil do return false
	defer delete(font_data, context.allocator)

	atlas := make([]u8, FONT_ATLAS_SIZE * FONT_ATLAS_SIZE)
	defer delete(atlas)

	ret := STBTT.BakeFontBitmap(
		raw_data(font_data),
		0,
		size,
		raw_data(atlas),
		FONT_ATLAS_SIZE,
		FONT_ATLAS_SIZE,
		32,
		96,
		&window.font.char_data[0],
	)
	if ret <= 0 do return false

	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.R8Unorm,
		FONT_ATLAS_SIZE,
		FONT_ATLAS_SIZE,
		false,
	)
	desc->setStorageMode(.Shared)
	window.font_texture = window.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {FONT_ATLAS_SIZE, FONT_ATLAS_SIZE, 1},
	}
	window.font_texture->replaceRegion(region, 0, raw_data(atlas), FONT_ATLAS_SIZE)

	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSAddressMode(.ClampToZero)
	samp_desc->setTAddressMode(.ClampToZero)
	window.font_sampler = window.device->newSamplerState(samp_desc)

	return true
}

assets_load_font :: proc(path: string, size: f32) -> bool {
	font_data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil do return false
	defer delete(font_data, context.allocator)

	app.font_new.texture_size = 1024
	app.font_new.line_height = size

	app.font_new.bitmap = make([]u8, app.font_new.texture_size * app.font_new.texture_size)
	app.font_new.char_data = make([]STBTT.packedchar, CharAmount)

	pack_context := new(STBTT.pack_context, context.temp_allocator)
	STBTT.PackBegin(
		pack_context,
		&app.font_new.bitmap[0],
		app.font_new.texture_size,
		app.font_new.texture_size,
		0,
		1,
		nil,
	)
	STBTT.PackSetOversampling(pack_context, 1, 1)

	STBTT.PackFontRange(
		pack_context,
		&font_data[0],
		0,
		128,
		CharAtStart,
		CharAmount,
		&app.font_new.char_data[0],
	)
	STBTT.PackEnd(pack_context)

	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.R8Unorm,
		FONT_ATLAS_SIZE,
		FONT_ATLAS_SIZE,
		false,
	)
	desc->setStorageMode(.Shared)
	app.font_texture = app.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {FONT_ATLAS_SIZE, FONT_ATLAS_SIZE, 1},
	}
	app.font_texture->replaceRegion(region, 0, raw_data(app.font_new.bitmap), FONT_ATLAS_SIZE)

	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSAddressMode(.ClampToZero)
	samp_desc->setTAddressMode(.ClampToZero)
	app.font_sampler = app.device->newSamplerState(samp_desc)

	STBI.write_png(
		"test.png",
		1024,
		1024,
		1,
		raw_data(app.font_new.bitmap),
		pack_context.stride_in_bytes,
	)

	return true
}

CharAtStart :: 32
CharAmount :: 95
