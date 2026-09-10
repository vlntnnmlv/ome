package omecore

import "base:runtime"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

import "ome:core/handle_map"

TextureManager :: struct {
	device:    ^MTL.Device,
	textures:  handle_map.HandleMap(Texture, TextureHandle),
	resources: [dynamic]^MTL.Resource,
	sampler:   ^MTL.SamplerState,
	encoder:   ^MTL.ArgumentEncoder,
	arguments: ^MTL.Buffer,
}

texture_manager_create :: proc(
	device: ^MTL.Device,
	fragment_fn: ^MTL.Function,
) -> ^TextureManager {
	texture_manager := new(TextureManager)
	texture_map, err := handle_map.make(Texture, TextureHandle)
	assert(err == runtime.Allocator_Error.None)

	texture_manager.textures = texture_map
	texture_manager.resources = make([dynamic]^MTL.Resource)

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

	for i in 0 ..< MAX_TEXTURES {
		texture_manager.encoder->setTexture(nil, cast(NS.UInteger)i)
	}

	clear(&texture_manager.resources)

	it := handle_map.make_iter(&texture_manager.textures)
	for texture in handle_map.iter(&it) {
		assert(texture.handle.idx < MAX_TEXTURES)

		texture_manager.encoder->setTexture(texture.data, cast(NS.UInteger)texture.handle.idx)
		append(&texture_manager.resources, cast(^MTL.Resource)texture.data)
	}

	texture_manager.encoder->setSamplerState(texture_manager.sampler, MAX_TEXTURES)
}

texture_manager_delete :: proc(texture_manager: ^TextureManager) {
	it := handle_map.make_iter(&texture_manager.textures)
	for texture in handle_map.iter(&it) {
		texture.data->release()
		delete(texture.name)
	}

	handle_map.delete(&texture_manager.textures)
	texture_manager.sampler->release()
	texture_manager.encoder->release()
	texture_manager.arguments->release()

	delete(texture_manager.resources)
}
