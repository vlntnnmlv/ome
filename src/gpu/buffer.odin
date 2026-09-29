package omegpu

import "core:mem"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

@(private)
INITIAL_BUFFER_SIZE :: 1024

@(private)
GPU_BUFFERS_RING_SIZE :: 3

@(private)
Buffer :: struct($T: typeid) {
	gpu_ring: [GPU_BUFFERS_RING_SIZE]^MTL.Buffer,
	caps:     [GPU_BUFFERS_RING_SIZE]int,
	device:   ^MTL.Device,
}

@(private)
buffer_create :: proc($T: typeid, device: ^MTL.Device) -> Buffer(T) {
	buffer: Buffer(T)
	buffer.device = device
	buffer.caps = INITIAL_BUFFER_SIZE
	for slot in 0 ..< GPU_BUFFERS_RING_SIZE {
		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			NS.UInteger(buffer.caps[slot]) * size_of(T),
			{},
		)
	}

	return buffer
}

@(private)
buffer_upload :: proc(buffer: ^Buffer($T), slot: int, data: []T) {
	if buffer.caps[slot] < len(data) {
		for buffer.caps[slot] < len(data) {
			buffer.caps[slot] *= 2
		}
		buffer.gpu_ring[slot]->release()
		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			NS.UInteger(buffer.caps[slot]) * size_of(T),
			{},
		)
	}

	contents := buffer.gpu_ring[slot]->contents()
	mem.copy(raw_data(contents), raw_data(data), len(data) * size_of(T))
}

@(private)
buffer_destroy :: proc(buffer: ^Buffer($T)) {
	for gpu in buffer.gpu_ring {
		gpu->release()
	}
}
