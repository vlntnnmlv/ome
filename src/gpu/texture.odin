package omegpu

import "core:log"
import "core:strings"

import vk "vendor:vulkan"

import "ome:core"
import "ome:handle_map"

MAX_TEXTURES :: 256

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
Texture :: struct {
	handle:             TextureHandle,
	image:              vk.Image,
	memory:             vk.DeviceMemory,
	view:               vk.ImageView,
	width:              u32,
	height:             u32,
	format:             PixelFormat,
	layout_initialized: bool, // false until the first upload has been recorded
}

@(private)
pixel_format_to_vulkan :: proc(pixel_format: PixelFormat) -> vk.Format {
	switch pixel_format {
	case .R8_Unorm:
		return .R8_UNORM
	case .RGBA8_Unorm_sRGB:
		return .R8G8B8A8_SRGB
	}
	return .UNDEFINED
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

	device := bind_table.device
	texture := Texture {
		width  = u32(texture_data.width),
		height = u32(texture_data.height),
		format = format,
	}
	if !texture_create_native(device, &texture, texture_data.name) {
		return {}, .Load
	}

	handle, err := handle_map.add(&bind_table.textures, texture)
	ensure(err == nil)
	bind_table_set_slot(bind_table, handle.idx, texture.view)

	size := int(texture_data.width * texture_data.height * pixel_format_to_channels(format))
	bytes := make([]u8, size)
	copy(bytes, texture_data.pixels[:size])
	upload_queue_push(&device.uploads, handle, {0, 0}, {texture.width, texture.height}, bytes)

	return handle, .None
}

texture_write_region :: proc(
	bind_table: ^BindTable,
	handle: TextureHandle,
	rect: core.Rect,
	pixels: [^]byte,
	source_width: int,
	format: PixelFormat,
) {
	if !handle_map.valid(bind_table.textures, handle) {
		return
	}

	channels := int(pixel_format_to_channels(format))
	x, y, w, h := int(rect.x), int(rect.y), int(rect.w), int(rect.h)
	source_stride := source_width * channels
	row_size := w * channels

	bytes := make([]u8, row_size * h)
	for row in 0 ..< h {
		source := (y + row) * source_stride + x * channels
		copy(bytes[row * row_size:][:row_size], pixels[source:source + row_size])
	}

	upload_queue_push(
		&bind_table.device.uploads,
		handle,
		{i32(x), i32(y)},
		{u32(w), u32(h)},
		bytes,
	)
}

texture_destroy :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	if !handle_map.valid(bind_table.textures, handle) {
		return
	}

	append(&bind_table.pending, PendingRelease{handle, bind_table.frame_number})
}

@(private = "file")
texture_create_native :: proc(device: ^Device, texture: ^Texture, name: string) -> bool {
	ok := false
	defer if !ok {
		texture_release_native(device, texture)
	}

	format := pixel_format_to_vulkan(texture.format)
	image_info := vk.ImageCreateInfo {
		sType         = .IMAGE_CREATE_INFO,
		imageType     = .D2,
		format        = format,
		extent        = {texture.width, texture.height, 1},
		mipLevels     = 1,
		arrayLayers   = 1,
		samples       = {._1},
		tiling        = .OPTIMAL,
		usage         = {.SAMPLED, .TRANSFER_DST},
		sharingMode   = .EXCLUSIVE,
		initialLayout = .UNDEFINED,
	}
	result := vk.CreateImage(device.handle, &image_info, nil, &texture.image)
	if !device_vulkan_ok(result, "vkCreateImage") {
		return false
	}

	requirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(device.handle, texture.image, &requirements)
	memory_type, found := device_find_memory_type(
		device.physical,
		requirements.memoryTypeBits,
		{.DEVICE_LOCAL},
	)
	if !found {
		log.errorf("gpu/texture: no device-local memory type for '%s'", name)
		return false
	}

	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = requirements.size,
		memoryTypeIndex = memory_type,
	}
	result = vk.AllocateMemory(device.handle, &allocate_info, nil, &texture.memory)
	if !device_vulkan_ok(result, "vkAllocateMemory") {
		return false
	}
	vk.BindImageMemory(device.handle, texture.image, texture.memory, 0)

	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = texture.image,
		viewType = .D2,
		format = format,
		subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
	}
	result = vk.CreateImageView(device.handle, &view_info, nil, &texture.view)
	if !device_vulkan_ok(result, "vkCreateImageView") {
		return false
	}

	when VALIDATION {
		name_info := vk.DebugUtilsObjectNameInfoEXT {
			sType        = .DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
			objectType   = .IMAGE,
			objectHandle = u64(texture.image),
			pObjectName  = strings.clone_to_cstring(name, context.temp_allocator),
		}
		vk.SetDebugUtilsObjectNameEXT(device.handle, &name_info)
	}

	ok = true
	return true
}

@(private)
texture_release_native :: proc(device: ^Device, texture: ^Texture) {
	vk.DestroyImageView(device.handle, texture.view, nil)
	vk.DestroyImage(device.handle, texture.image, nil)
	vk.FreeMemory(device.handle, texture.memory, nil)
	texture.view = 0
	texture.image = 0
	texture.memory = 0
}
