package omeassets

import "core:log"
import "core:strings"

import STBI "vendor:stb/image"

import "ome:gpu"
import "ome:handle_map"

MAX_IMAGE_SIZE :: 8192

ImageHandle :: distinct handle_map.Handle

Image :: struct {
	handle:         ImageHandle,
	texture_handle: gpu.TextureHandle,
	name:           string,
	size:           [2]f32,
}

@(private)
image_load :: proc(
	image: ^Image,
	bind_table: ^gpu.BindTable,
	path: string,
	name: string,
) -> Error {
	width, height, channels: i32
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	pixels := STBI.load(cpath, &width, &height, &channels, 4)

	if pixels == nil {
		log.errorf(
			"assets/image: failed to load image '%s' with error: %s",
			path,
			STBI.failure_reason(),
		)
		return .File
	}
	defer STBI.image_free(pixels)

	if width > MAX_IMAGE_SIZE || height > MAX_IMAGE_SIZE {
		log.errorf(
			"assets/image: image '%s' is too big (%dx%d), max size is %d",
			path,
			width,
			height,
			MAX_IMAGE_SIZE,
		)
		return .Pack
	}

	texture_handle, err := gpu.texture_create_from_data(
		bind_table,
		gpu.TextureData{name = name, pixels = pixels, width = width, height = height},
		gpu.PixelFormat.RGBA8_Unorm_sRGB,
	)

	if err != .None {
		return .GPU
	}

	image.texture_handle = texture_handle
	image.name = strings.clone(name)
	image.size = {f32(width), f32(height)}

	return .None
}

@(private)
image_destroy :: proc(image: ^Image, bind_table: ^gpu.BindTable) {
	gpu.texture_destroy(bind_table, image.texture_handle)
	delete(image.name)
}
