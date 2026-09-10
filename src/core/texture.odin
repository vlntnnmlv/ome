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
	w:          i32,
	h:          i32,
	channels:   i32,
	in_atlas:   bool,
	atlas_rect: Rect,
}

TextureManager :: struct {
	textures:      [dynamic]^MTL.Texture,
	texture_names: [dynamic]string,
	sampler:       ^MTL.SamplerState,
	encoder:       ^MTL.ArgumentEncoder,
	arguments:     ^MTL.Buffer,
}

TextureHandle :: distinct u32

texture_manager_create :: proc() -> ^TextureManager {
	texture_manager := new(TextureManager)
	texture_manager.textures = make([dynamic]^MTL.Texture)

	return texture_manager
}

texture_manager_init :: proc(
	texture_manager: ^TextureManager,
	renderer: ^Renderer,
	fragment_fn: ^MTL.Function,
) {
	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSupportArgumentBuffers(true)

	texture_manager.sampler = renderer.device->newSamplerState(samp_desc)
	texture_manager.encoder = fragment_fn->newArgumentEncoder(0)
	texture_manager.arguments = renderer.device->newBufferWithLength(
		texture_manager.encoder->encodedLength(),
		MTL.ResourceStorageModeShared,
	)

	texture_manager_rebuild(texture_manager)
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

texture_create :: proc(renderer: ^Renderer, path: string, name: string) -> TextureHandle {
	w, h, channels: i32

	cpath := strings.clone_to_cstring(path)
	pixels := STBI.load(cpath, &w, &h, &channels, 4)
	defer STBI.image_free(pixels)
	defer delete(cpath)

	texture_data := TextureData {
		pixels   = pixels,
		w        = w,
		h        = h,
		channels = channels,
		name     = name,
	}

	return texture_create_from_data(renderer, texture_data)
}

texture_create_from_data :: proc(renderer: ^Renderer, texture_data: TextureData) -> TextureHandle {
	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.RGBA8Unorm_sRGB,
		cast(NS.UInteger)texture_data.w,
		cast(NS.UInteger)texture_data.h,
		false,
	)
	desc->setStorageMode(.Shared)
	desc->setUsage({.ShaderRead})

	texture := renderer.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)texture_data.w, cast(NS.Integer)texture_data.h, 1},
	}
	texture->replaceRegion(region, 0, texture_data.pixels, cast(NS.UInteger)texture_data.w * 4)

	append(&renderer.texture_manager.textures, texture)
	texture_manager_rebuild(renderer.texture_manager)

	handle := TextureHandle(len(renderer.texture_manager.textures) - 1)
	append(&renderer.texture_manager.texture_names, texture_data.name)
	return handle
}

texture_manager_delete :: proc(texture_manager: ^TextureManager) {
	for texture in texture_manager.textures {
		texture->release()
	}

	delete(texture_manager.textures)
	delete(texture_manager.texture_names)
}
