package omecore

import "base:runtime"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

import "ome:core/handle_map"

BindTable :: struct {
	device:    ^MTL.Device,
	textures:  handle_map.HandleMap(Texture, TextureHandle),
	resources: [dynamic]^MTL.Resource,
	sampler:   ^MTL.SamplerState,
	encoder:   ^MTL.ArgumentEncoder,
	arguments: ^MTL.Buffer,
}

bind_table_create :: proc(device: ^MTL.Device, fragment_fn: ^MTL.Function) -> ^BindTable {
	bind_table := new(BindTable)
	texture_map, err := handle_map.make(Texture, TextureHandle)
	assert(err == runtime.Allocator_Error.None)

	bind_table.textures = texture_map
	bind_table.resources = make([dynamic]^MTL.Resource)

	samp_desc := NS.new(MTL.SamplerDescriptor)
	samp_desc->setMinFilter(.Linear)
	samp_desc->setMagFilter(.Linear)
	samp_desc->setSupportArgumentBuffers(true)

	bind_table.device = device

	bind_table.sampler = device->newSamplerState(samp_desc)
	bind_table.encoder = fragment_fn->newArgumentEncoder(0)
	bind_table.arguments = device->newBufferWithLength(
		bind_table.encoder->encodedLength(),
		MTL.ResourceStorageModeShared,
	)

	bind_table_rebuild(bind_table)

	return bind_table
}

bind_table_rebuild :: proc(bind_table: ^BindTable) {
	bind_table.encoder->setArgumentBufferWithOffset(bind_table.arguments, 0)

	for i in 0 ..< MAX_TEXTURES {
		bind_table.encoder->setTexture(nil, cast(NS.UInteger)i)
	}

	clear(&bind_table.resources)

	it := handle_map.make_iter(&bind_table.textures)
	for texture in handle_map.iter(&it) {
		assert(texture.handle.idx < MAX_TEXTURES)

		bind_table.encoder->setTexture(texture.data, cast(NS.UInteger)texture.handle.idx)
		append(&bind_table.resources, cast(^MTL.Resource)texture.data)
	}

	bind_table.encoder->setSamplerState(bind_table.sampler, MAX_TEXTURES)
}

bind_table_delete :: proc(bind_table: ^BindTable) {
	it := handle_map.make_iter(&bind_table.textures)
	for texture in handle_map.iter(&it) {
		texture.data->release()
	}

	handle_map.delete(&bind_table.textures)
	bind_table.sampler->release()
	bind_table.encoder->release()
	bind_table.arguments->release()

	delete(bind_table.resources)
}
