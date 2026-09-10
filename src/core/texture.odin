package omecore

import "core:strings"
import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"

MAX_TEXTURES :: 256

Texture :: struct {
	data: ^MTL.Texture,
	name: string,
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

TextureManager :: struct {
	device:        ^MTL.Device,
	textures:      [dynamic]^MTL.Texture,
	texture_names: [dynamic]string,
	sampler:       ^MTL.SamplerState,
	encoder:       ^MTL.ArgumentEncoder,
	arguments:     ^MTL.Buffer,
}

TextureHandle :: distinct u32

texture_manager_create :: proc(
	device: ^MTL.Device,
	fragment_fn: ^MTL.Function,
) -> ^TextureManager {
	texture_manager := new(TextureManager)
	texture_manager.textures = make([dynamic]^MTL.Texture)

	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSupportArgumentBuffers(true)

	texture_manager.device = device

	texture_manager.sampler = device->newSamplerState(samp_desc)
	texture_manager.encoder = fragment_fn->newArgumentEncoder(0)
	texture_manager.arguments = device->newBufferWithLength(
		texture_manager.encoder->encodedLength(),
		MTL.ResourceStorageModeShared,
	)

	texture_manager_rebuild(texture_manager)

	return texture_manager
}

texture_manager_rebuild :: proc(texture_manager: ^TextureManager) {
	texture_manager.encoder->setArgumentBufferWithOffset(texture_manager.arguments, 0)
	i := 0
	for texture in texture_manager.textures {
		texture_manager.encoder->setTexture(texture, cast(NS.UInteger)i)
		i += 1
	}

	texture_manager.encoder->setSamplerState(texture_manager.sampler, MAX_TEXTURES)
}

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

	append(&texture_manager.textures, texture)
	texture_manager_rebuild(texture_manager)

	handle := TextureHandle(len(texture_manager.textures) - 1)
	append(&texture_manager.texture_names, texture_data.name)
	return handle
}

texture_manager_delete :: proc(texture_manager: ^TextureManager) {
	for texture in texture_manager.textures {
		texture->release()
	}

	delete(texture_manager.textures)
	delete(texture_manager.texture_names)
}
