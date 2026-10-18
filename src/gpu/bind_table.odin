package omegpu

import vk "vendor:vulkan"

import "ome:handle_map"

@(private)
PendingRelease :: struct {
	handle:       TextureHandle,
	frame_number: u64,
}

BindTable :: struct {
	device:       ^Device,
	textures:     handle_map.Map(Texture, TextureHandle),
	sampler:      vk.Sampler,
	layout:       vk.DescriptorSetLayout,
	pool:         vk.DescriptorPool,
	set:          vk.DescriptorSet,
	pending:      [dynamic]PendingRelease,
	frame_number: u64,
}

@(private)
bind_table_create :: proc(device: ^Device) -> (^BindTable, bool) {
	bind_table := new(BindTable)
	bind_table.device = device
	bind_table.pending = make([dynamic]PendingRelease)

	texture_map, err := handle_map.make(Texture, TextureHandle)
	ensure(err == nil)
	bind_table.textures = texture_map

	ok := false
	defer if !ok {
		bind_table_destroy(bind_table)
	}

	sampler_info := vk.SamplerCreateInfo {
		sType        = .SAMPLER_CREATE_INFO,
		magFilter    = .NEAREST,
		minFilter    = .NEAREST,
		mipmapMode   = .NEAREST,
		addressModeU = .CLAMP_TO_EDGE,
		addressModeV = .CLAMP_TO_EDGE,
		addressModeW = .CLAMP_TO_EDGE,
	}
	result := vk.CreateSampler(device.handle, &sampler_info, nil, &bind_table.sampler)
	if !device_vulkan_ok(result, "vkCreateSampler") {
		return nil, false
	}

	bindings := [2]vk.DescriptorSetLayoutBinding {
		{
			binding = 0,
			descriptorType = .SAMPLED_IMAGE,
			descriptorCount = MAX_TEXTURES,
			stageFlags = {.FRAGMENT},
		},
		{
			binding = 1,
			descriptorType = .SAMPLER,
			descriptorCount = 1,
			stageFlags = {.FRAGMENT},
			pImmutableSamplers = &bind_table.sampler,
		},
	}
	binding_flags := [2]vk.DescriptorBindingFlags {
		{.PARTIALLY_BOUND, .UPDATE_AFTER_BIND, .UPDATE_UNUSED_WHILE_PENDING},
		{},
	}
	flags_info := vk.DescriptorSetLayoutBindingFlagsCreateInfo {
		sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
		bindingCount  = len(binding_flags),
		pBindingFlags = &binding_flags[0],
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		pNext        = &flags_info,
		flags        = {.UPDATE_AFTER_BIND_POOL},
		bindingCount = len(bindings),
		pBindings    = &bindings[0],
	}
	result = vk.CreateDescriptorSetLayout(device.handle, &layout_info, nil, &bind_table.layout)
	if !device_vulkan_ok(result, "vkCreateDescriptorSetLayout") {
		return nil, false
	}

	pool_sizes := [2]vk.DescriptorPoolSize {
		{type = .SAMPLED_IMAGE, descriptorCount = MAX_TEXTURES},
		{type = .SAMPLER, descriptorCount = 1},
	}
	pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		flags         = {.UPDATE_AFTER_BIND},
		maxSets       = 1,
		poolSizeCount = len(pool_sizes),
		pPoolSizes    = &pool_sizes[0],
	}
	result = vk.CreateDescriptorPool(device.handle, &pool_info, nil, &bind_table.pool)
	if !device_vulkan_ok(result, "vkCreateDescriptorPool") {
		return nil, false
	}

	allocate_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = bind_table.pool,
		descriptorSetCount = 1,
		pSetLayouts        = &bind_table.layout,
	}
	result = vk.AllocateDescriptorSets(device.handle, &allocate_info, &bind_table.set)
	if !device_vulkan_ok(result, "vkAllocateDescriptorSets") {
		return nil, false
	}

	ok = true
	return bind_table, true
}

// Runs in device_begin after the slot fence wait, so after RING_SIZE frames
// nothing in flight can still index a released texture.
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
bind_table_set_slot :: proc(bind_table: ^BindTable, idx: u32, view: vk.ImageView) {
	image_info := vk.DescriptorImageInfo {
		imageView   = view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}
	write := vk.WriteDescriptorSet {
		sType           = .WRITE_DESCRIPTOR_SET,
		dstSet          = bind_table.set,
		dstBinding      = 0,
		dstArrayElement = idx,
		descriptorCount = 1,
		descriptorType  = .SAMPLED_IMAGE,
		pImageInfo      = &image_info,
	}
	vk.UpdateDescriptorSets(bind_table.device.handle, 1, &write, 0, nil)
}

@(private)
bind_table_release :: proc(bind_table: ^BindTable, handle: TextureHandle) {
	texture := handle_map.get(bind_table.textures, handle)
	if texture == nil {
		return
	}

	texture_release_native(bind_table.device, texture)
	handle_map.remove(&bind_table.textures, handle)
}

@(private)
bind_table_destroy :: proc(bind_table: ^BindTable) {
	device := bind_table.device

	it := handle_map.make_iter(&bind_table.textures)
	for texture in handle_map.iter(&it) {
		texture_release_native(device, texture)
	}
	handle_map.delete(&bind_table.textures)

	vk.DestroyDescriptorPool(device.handle, bind_table.pool, nil) // frees the set
	vk.DestroyDescriptorSetLayout(device.handle, bind_table.layout, nil)
	vk.DestroySampler(device.handle, bind_table.sampler, nil)

	delete(bind_table.pending)
	free(bind_table)
}
