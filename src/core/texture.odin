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
	texture_manager: ^TextureManager,
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

	return texture_create_from_data(texture_manager, texture_data, format)
}

TextureFormat :: struct {
	pixels:   MTL.PixelFormat,
	channels: i32,
}

texture_create_from_data :: proc(
	texture_manager: ^TextureManager,
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

	texture := texture_manager.device->newTextureWithDescriptor(desc)
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

	handle, err := handle_map.add(&texture_manager.textures, Texture{data = texture})
	assert(err == runtime.Allocator_Error.None)

	texture_manager_rebuild(texture_manager)

	return handle
}

texture_write :: proc(
	tm: ^TextureManager,
	handle: TextureHandle,
	pixels: [^]byte,
	format: TextureFormat,
) {
	texture := handle_map.get(tm.textures, handle)
	if texture == nil do return

	w := texture.data->width()
	h := texture.data->height()
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)w, cast(NS.Integer)h, 1},
	}
	texture.data->replaceRegion(region, 0, pixels, w * cast(NS.UInteger)format.channels)
}

// texture_find_by_name :: proc(tm: ^TextureManager, name: string) -> (TextureHandle, bool) {
// 	it := handle_map.make_iter(&tm.textures)
// 	for texture in handle_map.iter(&it) {
// 		if texture.name == name do return texture.handle, true
// 	}
// 	return {}, false
// }

texture_destroy :: proc(tm: ^TextureManager, handle: TextureHandle) {
	texture := handle_map.get(tm.textures, handle)
	if texture == nil {
		return
	}

	texture.data->release()
	handle_map.remove(&tm.textures, handle)

	texture_manager_rebuild(tm)
}
