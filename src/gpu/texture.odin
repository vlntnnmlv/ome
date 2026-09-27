package omegpu

import "core:log"
import "core:strings"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"

import "ome:core"
import "ome:handle_map"

MAX_TEXTURES :: 256

Texture :: struct {
	handle: TextureHandle,
	native: ^MTL.Texture,
}

TextureData :: struct {
	name:       string,
	pixels:     [^]byte,
	width:      i32,
	height:     i32,
	channels:   i32,
	in_atlas:   bool,
	atlas_rect: core.Rect,
}

TextureHandle :: distinct handle_map.Handle

texture_create :: proc(
	bind_table: ^BindTable,
	path: string,
	name: string,
	format: PixelFormat = .RGBA8_Unorm_sRGB,
) -> (
	TextureHandle,
	Error,
) {
	w, h, channels: i32

	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	pixels := STBI.load(cpath, &w, &h, &channels, pixel_format_to_channels(format))
	defer STBI.image_free(pixels)
	if pixels == nil {
		log.errorf(
			"gpu/texture: failed to load texture at path '%s' with error %s",
			path,
			STBI.failure_reason(),
		)
		return {}, .Load
	}

	texture_data := TextureData {
		pixels   = pixels,
		width    = w,
		height   = h,
		channels = channels,
		name     = name,
	}

	return texture_create_from_data(bind_table, texture_data, format)
}

PixelFormat :: enum {
	R8_Unorm = 0,
	RGBA8_Unorm_sRGB,
}

@(private)
pixel_format_to_metal :: proc(pixel_format: PixelFormat) -> MTL.PixelFormat {
	switch pixel_format {
	case .R8_Unorm:
		return .R8Unorm
	case .RGBA8_Unorm_sRGB:
		return .RGBA8Unorm_sRGB
	}

	return .Invalid
}

@(private)
pixel_format_to_channels :: proc(pixel_format: PixelFormat) -> i32 {
	switch pixel_format {
	case .R8_Unorm:
		return 1
	case .RGBA8_Unorm_sRGB:
		return 4
	}

	return 0
}

texture_create_from_data :: proc(
	bind_table: ^BindTable,
	texture_data: TextureData,
	format: PixelFormat = .RGBA8_Unorm_sRGB,
) -> (
	TextureHandle,
	Error,
) {
	if handle_map.len(bind_table.textures) >= MAX_TEXTURES - 1 {
		log.errorf(
			"gpu/texture: texture limit (%d) reached, can't create '%s'",
			MAX_TEXTURES - 1,
			texture_data.name,
		)
		return {}, .Texture_Limit
	}
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		pixel_format_to_metal(format),
		NS.UInteger(texture_data.width),
		NS.UInteger(texture_data.height),
		false,
	)
	desc->setStorageMode(.Shared)
	desc->setUsage({.ShaderRead})

	texture := bind_table.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {NS.Integer(texture_data.width), NS.Integer(texture_data.height), 1},
	}
	texture->replaceRegion(
		region,
		0,
		texture_data.pixels,
		NS.UInteger(texture_data.width * pixel_format_to_channels(format)),
	)

	handle, err := handle_map.add(&bind_table.textures, Texture{native = texture})
	ensure(err == nil)

	bind_table_rebuild(bind_table)

	return handle, .None
}

texture_write :: proc(
	bind_table: ^BindTable,
	handle: TextureHandle,
	pixels: [^]byte,
	format: PixelFormat,
) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	w := texture.native->width()
	h := texture.native->height()
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {NS.Integer(w), NS.Integer(h), 1},
	}
	texture.native->replaceRegion(
		region,
		0,
		pixels,
		w * NS.UInteger(pixel_format_to_channels(format)),
	)
}

texture_size :: proc(bind_table: ^BindTable, handle: TextureHandle) -> ([2]f32, bool) {
	tex := handle_map.get(bind_table.textures, handle)
	if tex == nil {
		return {0, 0}, false
	}

	tw := f32(tex.native->width())
	th := f32(tex.native->height())
	return {tw, th}, true
}

texture_destroy :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	texture.native->release()
	handle_map.remove(&bind_table.textures, handle)

	bind_table_rebuild(bind_table)
}
