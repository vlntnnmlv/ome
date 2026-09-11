package omegpu

import "core:mem"
// import "core:slice"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

INITIAL_BUFFER_SIZE :: 1024
GPU_BUFFERS_RING_SIZE :: 3

GPUBuffer :: struct($T: typeid) {
	cpu:      [dynamic]T,
	gpu_ring: [GPU_BUFFERS_RING_SIZE]^MTL.Buffer,
	caps:     [GPU_BUFFERS_RING_SIZE]int,
	device:   ^MTL.Device,
}

gpu_buffer_create :: proc($T: typeid, device: ^MTL.Device) -> GPUBuffer(T) {
	buffer: GPUBuffer(T)
	buffer.device = device
	buffer.cpu = make([dynamic]T, 0, INITIAL_BUFFER_SIZE, context.allocator)

	buffer.caps = INITIAL_BUFFER_SIZE
	for slot in 0 ..< GPU_BUFFERS_RING_SIZE {
		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			cast(NS.UInteger)buffer.caps[slot] * size_of(T),
			{},
		)
	}

	return buffer
}

gpu_buffer_append :: proc(buffer: ^GPUBuffer($T), data: []T) {
	append(&buffer.cpu, ..data)
}

gpu_buffer_fill_zeros_n :: proc(buffer: ^GPUBuffer($T), n: int) {
	old := len(buffer.cpu)
	resize(&buffer.cpu, old + n)
	slice.fill(buffer.cpu[old:], T{})
}

gpu_buffer_fill_n :: proc(buffer: ^GPUBuffer($T), value: T, n: int) {
	old := len(buffer.cpu)
	resize(&buffer.cpu, old + n)
	slice.fill(buffer.cpu[old:], value)
}

gpu_buffer_clear :: proc(buffer: ^GPUBuffer($T)) {
	clear(&buffer.cpu)
}

gpu_buffer_submit :: proc(buffer: ^GPUBuffer($T), slot: int) {
	if buffer.caps[slot] < len(buffer.cpu) {
		buffer.gpu_ring[slot]->release()
		for buffer.caps[slot] < len(buffer.cpu) do buffer.caps[slot] *= 2

		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			cast(NS.UInteger)buffer.caps[slot] * size_of(T),
			{},
		)
	}

	contents := buffer.gpu_ring[slot]->contents()
	mem.copy(raw_data(contents), raw_data(buffer.cpu), len(buffer.cpu) * size_of(T))
}

gpu_buffer_delete :: proc(buffer: ^GPUBuffer($T)) {
	delete(buffer.cpu)

	for gpu in buffer.gpu_ring {
		gpu->release()
	}
}
