package omegpu

import "core:log"
import "core:mem"

import vk "vendor:vulkan"

@(private)
INITIAL_BUFFER_SIZE :: 1024 // elements

@(private)
GPU_BUFFERS_RING_SIZE :: 3

@(private)
BufferSlot :: struct {
	handle: vk.Buffer,
	memory: vk.DeviceMemory,
	mapped: rawptr,
	size:   int, // bytes
}

@(private)
Buffer :: struct($T: typeid) {
	ring:   [GPU_BUFFERS_RING_SIZE]BufferSlot,
	device: ^Device,
	usage:  vk.BufferUsageFlags,
}

@(private)
buffer_create :: proc(
	$T: typeid,
	device: ^Device,
	usage: vk.BufferUsageFlags,
) -> (
	buffer: Buffer(T),
	ok: bool,
) {
	buffer.device = device
	buffer.usage = usage
	for &slot in buffer.ring {
		slot, ok = buffer_slot_create(device, INITIAL_BUFFER_SIZE * size_of(T), usage)
		if !ok {
			buffer_destroy(&buffer)
			return {}, false
		}
	}
	return buffer, true
}

// Growing destroys the slot's old buffer. That's only safe because
// device_begin waited on this slot's fence before frame_submit runs.
@(private)
buffer_upload :: proc(buffer: ^Buffer($T), slot: int, data: []T) -> bool {
	size := len(data) * size_of(T)
	current := &buffer.ring[slot]

	if current.size < size {
		new_size := max(current.size, INITIAL_BUFFER_SIZE * size_of(T))
		for new_size < size {
			new_size *= 2
		}
		buffer_slot_destroy(buffer.device, current)
		current^ = buffer_slot_create(buffer.device, new_size, buffer.usage) or_return
	}

	mem.copy(current.mapped, raw_data(data), size)
	return true
}

@(private)
buffer_destroy :: proc(buffer: ^Buffer($T)) {
	for &slot in buffer.ring {
		buffer_slot_destroy(buffer.device, &slot)
	}
}

@(private)
buffer_slot_create :: proc(
	device: ^Device,
	size: int,
	usage: vk.BufferUsageFlags,
) -> (
	slot: BufferSlot,
	ok: bool,
) {
	defer if !ok {
		buffer_slot_destroy(device, &slot)
	}

	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = vk.DeviceSize(size),
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}
	result := vk.CreateBuffer(device.handle, &buffer_info, nil, &slot.handle)
	if !device_vulkan_ok(result, "vkCreateBuffer") {
		return
	}

	requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device.handle, slot.handle, &requirements)
	memory_type, found := device_find_memory_type(
		device.physical,
		requirements.memoryTypeBits,
		{.HOST_VISIBLE, .HOST_COHERENT},
	)
	if !found {
		log.errorf("gpu/buffer: no host-visible coherent memory type")
		return
	}

	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = requirements.size,
		memoryTypeIndex = memory_type,
	}
	result = vk.AllocateMemory(device.handle, &allocate_info, nil, &slot.memory)
	if !device_vulkan_ok(result, "vkAllocateMemory") {
		return
	}

	vk.BindBufferMemory(device.handle, slot.handle, slot.memory, 0)
	result = vk.MapMemory(device.handle, slot.memory, 0, vk.DeviceSize(size), {}, &slot.mapped)
	if !device_vulkan_ok(result, "vkMapMemory") {
		return
	}

	slot.size = size
	ok = true
	return
}

@(private)
buffer_slot_destroy :: proc(device: ^Device, slot: ^BufferSlot) {
	if slot.mapped != nil {
		vk.UnmapMemory(device.handle, slot.memory)
	}
	vk.DestroyBuffer(device.handle, slot.handle, nil)
	vk.FreeMemory(device.handle, slot.memory, nil)
	slot^ = {}
}
