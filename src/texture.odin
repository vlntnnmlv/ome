package ome

import "core:strings"
import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import STBI "vendor:stb/image"

MAX_TEXTURES :: 256

TextureManager :: struct {
	textures:  [dynamic]^MTL.Texture,
	sampler:   ^MTL.SamplerState,
	encoder:   ^MTL.ArgumentEncoder,
	arguments: ^MTL.Buffer,
}

TextureHandle :: distinct u32

texture_manager_create :: proc() -> ^TextureManager {
	texture_manager := new(TextureManager)
	texture_manager.textures = make([dynamic]^MTL.Texture)

	return texture_manager
}

texture_manager_init :: proc(
	app: ^App,
	texture_manager: ^TextureManager,
	fragment_fn: ^MTL.Function,
) {
	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSupportArgumentBuffers(true)

	texture_manager.sampler = app.renderer.device->newSamplerState(samp_desc)
	texture_manager.encoder = fragment_fn->newArgumentEncoder(0)
	texture_manager.arguments = app.renderer.device->newBufferWithLength(
		texture_manager.encoder->encodedLength(),
		MTL.ResourceStorageModeShared,
	)

	texture_manager_rebuild(texture_manager)
}

texture_manager_rebuild :: proc(texture_manager: ^TextureManager) {
	texture_manager.encoder->setArgumentBufferWithOffset(texture_manager.arguments, 0)
	for texture, i in texture_manager.textures {
		texture_manager.encoder->setTexture(texture, cast(NS.UInteger)i)
	}

	texture_manager.encoder->setSamplerState(texture_manager.sampler, MAX_TEXTURES)
}

texture_create :: proc(
	app: ^App,
	texture_manager: ^TextureManager,
	path: string,
) -> TextureHandle {
	w, h, channels: i32
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)

	pixels := STBI.load(cpath, &w, &h, &channels, 4)
	defer STBI.image_free(pixels)

	desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
		.RGBA8Unorm_sRGB,
		cast(NS.UInteger)w,
		cast(NS.UInteger)h,
		false,
	)
	desc->setStorageMode(.Shared)
	desc->setUsage({.ShaderRead})

	texture := app.renderer.device->newTextureWithDescriptor(desc)
	region := MTL.Region {
		origin = {0, 0, 0},
		size   = {cast(NS.Integer)w, cast(NS.Integer)h, 1},
	}
	texture->replaceRegion(region, 0, pixels, cast(NS.UInteger)w * 4)
	append(&texture_manager.textures, texture)

	texture_manager_rebuild(texture_manager)
	return TextureHandle(len(texture_manager.textures) - 1)
}

texture_manager_delete :: proc(texture_manager: ^TextureManager) {
	for texture in texture_manager.textures {
		texture->release()
	}

	delete(texture_manager.textures)
}
