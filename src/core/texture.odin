package omecore

import "base:runtime"
import "core:strings"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"

import "ome:core/handle_map"

MAX_TEXTURES :: 256

Texture :: struct {
	handle: TextureHandle,
	data:   ^MTL.Texture,
}

TextureData :: struct {
	name:       string,
	pixels:     [^]byte,
	width:      i32,
	height:     i32,
	channels:   i32,
	in_atlas:   bool,
	atlas_rect: Rect,
}

TextureHandle :: distinct handle_map.Handle

texture_create :: proc(
	bind_table: ^BindTable,
	path: string,
	name: string,
	format: TextureFormat = {.RGBA8Unorm_sRGB, 4},
) -> TextureHandle {
	w, h, channels: i32

	cpath := strings.clone_to_cstring(path)
	pixels := STBI.load(cpath, &w, &h, &channels, format.channels)
	defer STBI.image_free(pixels)
	defer delete(cpath)

	texture_data := TextureData {
		pixels   = pixels,
		width    = w,
		height   = h,
		channels = channels,
		name     = name,
	}

	return texture_create_from_data(bind_table, texture_data, format)
}

TextureFormat :: struct {
	pixels:   MTL.PixelFormat,
	channels: i32,
}

texture_create_from_data :: proc(
	bind_table: ^BindTable,
	texture_data: TextureData,
	format: TextureFormat = {.RGBA8Unorm_sRGB, 4},
) -> TextureHandle {
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		format.pixels,
		cast(NS.UInteger)texture_data.width,
		cast(NS.UInteger)texture_data.height,
		false,
	)
	desc->setStorageMode(.Shared)
	desc->setUsage({.ShaderRead})

	texture := bind_table.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)texture_data.width, cast(NS.Integer)texture_data.height, 1},
	}
	texture->replaceRegion(
		region,
		0,
		texture_data.pixels,
		cast(NS.UInteger)(texture_data.width * format.channels),
	)

	handle, err := handle_map.add(&bind_table.textures, Texture{data = texture})
	assert(err == runtime.Allocator_Error.None)

	bind_table_rebuild(bind_table)

	return handle
}

texture_write :: proc(
	bind_table: ^BindTable,
	handle: TextureHandle,
	pixels: [^]byte,
	format: TextureFormat,
) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil do return

	w := texture.data->width()
	h := texture.data->height()
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)w, cast(NS.Integer)h, 1},
	}
	texture.data->replaceRegion(region, 0, pixels, w * cast(NS.UInteger)format.channels)
}

texture_destroy :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	texture.data->release()
	handle_map.remove(&bind_table.textures, handle)

	bind_table_rebuild(bind_table)
}
