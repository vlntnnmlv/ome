package omegpu

import "core:log"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

import "ome:core"
import "ome:handle_map"

MAX_TEXTURES :: 256

@(private)
Texture :: struct {
	handle: TextureHandle,
	native: ^MTL.Texture,
}

TextureData :: struct {
	name:   string,
	pixels: [^]byte,
	width:  i32,
	height: i32,
}

TextureHandle :: distinct handle_map.Handle

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
	label := NS.String.alloc()->initWithOdinString(string(texture_data.name))
	texture->setLabel(label)
	defer label->release()

	handle, err := handle_map.add(&bind_table.textures, Texture{native = texture})
	ensure(err == nil)

	bind_table_set_slot(bind_table, handle.idx, texture)
	append(&bind_table.resources, cast(^MTL.Resource)texture)

	return handle, .None
}

// texture_write :: proc(
// 	bind_table: ^BindTable,
// 	handle: TextureHandle,
// 	pixels: [^]byte,
// 	format: PixelFormat,
// ) {
// 	texture := handle_map.get(bind_table.textures, handle)
// 	if texture == nil {
// 		return
// 	}

// 	w := texture.native->width()
// 	h := texture.native->height()
// 	region := MTL.Region {
// 		origin = {0, 0, 0},
// 		size   = {NS.Integer(w), NS.Integer(h), 1},
// 	}
// 	texture.native->replaceRegion(
// 		region,
// 		0,
// 		pixels,
// 		w * NS.UInteger(pixel_format_to_channels(format)),
// 	)
// }

texture_write_region :: proc(
	bind_table: ^BindTable,
	handle: TextureHandle,
	rect: core.Rect,
	pixels: [^]byte,
	source_width: int,
	format: PixelFormat,
) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	channels := pixel_format_to_channels(format)
	x, y := int(rect.x), int(rect.y)
	bytes_per_row := source_width * int(channels)

	region := MTL.Region {
		origin = {NS.Integer(x), NS.Integer(y), 0},
		size   = {NS.Integer(rect.w), NS.Integer(rect.h), 1},
	}
	texture.native->replaceRegion(
		region,
		0,
		&pixels[y * bytes_per_row + x * int(channels)],
		NS.UInteger(bytes_per_row),
	)
}

// texture_size :: proc(bind_table: ^BindTable, handle: TextureHandle) -> ([2]f32, bool) {
// 	tex := handle_map.get(bind_table.textures, handle)
// 	if tex == nil {
// 		return {0, 0}, false
// 	}

// 	tw := f32(tex.native->width())
// 	th := f32(tex.native->height())
// 	return {tw, th}, true
// }

texture_destroy :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	if !handle_map.valid(bind_table.textures, handle) {
		return
	}

	append(&bind_table.pending, PendingRelease{handle, bind_table.frame_number})
}
