package omegpu

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

import "ome:handle_map"

PendingRelease :: struct {
	handle:       TextureHandle,
	frame_number: u64,
}

BindTable :: struct {
	device:       ^MTL.Device,
	textures:     handle_map.Map(Texture, TextureHandle),
	resources:    [dynamic]^MTL.Resource,
	sampler:      ^MTL.SamplerState,
	encoder:      ^MTL.ArgumentEncoder,
	arguments:    ^MTL.Buffer,
	pending:      [dynamic]PendingRelease,
	frame_number: u64,
}

@(private)
bind_table_create :: proc(device: ^MTL.Device, fragment_fn: ^MTL.Function) -> ^BindTable {
	bind_table := new(BindTable)
	texture_map, err := handle_map.make(Texture, TextureHandle)
	ensure(err == nil)

	bind_table.textures = texture_map
	bind_table.resources = make([dynamic]^MTL.Resource)
	bind_table.pending = make([dynamic]PendingRelease)

	sampler_descriptor := NS.new(MTL.SamplerDescriptor)
	sampler_descriptor->setMinFilter(.Nearest)
	sampler_descriptor->setMagFilter(.Nearest)
	sampler_descriptor->setSupportArgumentBuffers(true)

	bind_table.device = device

	bind_table.sampler = device->newSamplerState(sampler_descriptor)
	bind_table.encoder = fragment_fn->newArgumentEncoder(0)
	bind_table.arguments = device->newBufferWithLength(
		bind_table.encoder->encodedLength(),
		MTL.ResourceStorageModeShared,
	)

	bind_table_rebuild(bind_table)

	return bind_table
}

@(private)
bind_table_begin_frame :: proc(bind_table: ^BindTable) {
	bind_table.frame_number += 1

	#reverse for pending, i in bind_table.pending {
		if pending.frame_number + GPU_BUFFERS_RING_SIZE > bind_table.frame_number {
			continue
		}

		bind_table_release(bind_table, pending.handle)
		unordered_remove(&bind_table.pending, i)
	}
}

@(private)
bind_table_release :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	bind_table_set_slot(bind_table, handle.idx, nil)
	for resource, i in bind_table.resources {
		if resource == cast(^MTL.Resource)texture.native {
			unordered_remove(&bind_table.resources, i)
			break
		}
	}

	texture.native->release()
	handle_map.remove(&bind_table.textures, handle)
}

@(private)
bind_table_set_slot :: proc(bind_table: ^BindTable, idx: u32, texture: ^MTL.Texture) {
	bind_table.encoder->setArgumentBufferWithOffset(bind_table.arguments, 0)
	bind_table.encoder->setTexture(texture, NS.UInteger(idx))
}

@(private)
bind_table_rebuild :: proc(bind_table: ^BindTable) {
	bind_table.encoder->setArgumentBufferWithOffset(bind_table.arguments, 0)

	for i in 0 ..< MAX_TEXTURES {
		bind_table.encoder->setTexture(nil, NS.UInteger(i))
	}

	clear(&bind_table.resources)

	it := handle_map.make_iter(&bind_table.textures)
	for texture in handle_map.iter(&it) {
		assert(texture.handle.idx < MAX_TEXTURES)

		bind_table.encoder->setTexture(texture.native, NS.UInteger(texture.handle.idx))
		append(&bind_table.resources, cast(^MTL.Resource)texture.native)
	}

	bind_table.encoder->setSamplerState(bind_table.sampler, MAX_TEXTURES)
}

@(private)
bind_table_destroy :: proc(bind_table: ^BindTable) {
	it := handle_map.make_iter(&bind_table.textures)
	for texture in handle_map.iter(&it) {
		texture.native->release()
	}

	handle_map.delete(&bind_table.textures)
	bind_table.sampler->release()
	bind_table.encoder->release()
	bind_table.arguments->release()

	delete(bind_table.pending)
	delete(bind_table.resources)
	free(bind_table)
}
