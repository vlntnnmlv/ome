package omegpu

import "core:mem"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

INITIAL_BUFFER_SIZE :: 1024
GPU_BUFFERS_RING_SIZE :: 3

Buffer :: struct($T: typeid) {
	cpu:      [dynamic]T,
	gpu_ring: [GPU_BUFFERS_RING_SIZE]^MTL.Buffer,
	caps:     [GPU_BUFFERS_RING_SIZE]int,
	device:   ^MTL.Device,
}

buffer_create :: proc($T: typeid, device: ^MTL.Device) -> Buffer(T) {
	buffer: Buffer(T)
	buffer.device = device
	buffer.cpu = make([dynamic]T, 0, INITIAL_BUFFER_SIZE, context.allocator)

	buffer.caps = INITIAL_BUFFER_SIZE
	for slot in 0 ..< GPU_BUFFERS_RING_SIZE {
		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			NS.UInteger(buffer.caps[slot]) * size_of(T),
			{},
		)
	}

	return buffer
}

buffer_append :: proc(buffer: ^Buffer($T), data: []T) {
	append(&buffer.cpu, ..data)
}

buffer_reserve :: proc(buffer: ^Buffer($T), n: int) -> []T {
	old := len(buffer.cpu)
	err := non_zero_resize(&buffer.cpu, old + n)
	ensure(err == nil)
	return buffer.cpu[old:]
}

buffer_zeros :: proc(buffer: ^Buffer($T), n: int) {
	old := len(buffer.cpu)
	resize(&buffer.cpu, old + n)
	slice.fill(buffer.cpu[old:], T{})
}

buffer_fill :: proc(buffer: ^Buffer($T), value: T, n: int) {
	old := len(buffer.cpu)
	resize(&buffer.cpu, old + n)
	slice.fill(buffer.cpu[old:], value)
}

buffer_clear :: proc(buffer: ^Buffer($T)) {
	clear(&buffer.cpu)
}

buffer_submit :: proc(buffer: ^Buffer($T), slot: int) {
	if buffer.caps[slot] < len(buffer.cpu) {
		buffer.gpu_ring[slot]->release()
		for buffer.caps[slot] < len(buffer.cpu) {
			buffer.caps[slot] *= 2
		}

		buffer.gpu_ring[slot] = buffer.device->newBufferWithLength(
			NS.UInteger(buffer.caps[slot]) * size_of(T),
			{},
		)
	}

	contents := buffer.gpu_ring[slot]->contents()
	mem.copy(raw_data(contents), raw_data(buffer.cpu), len(buffer.cpu) * size_of(T))
}

buffer_destroy :: proc(buffer: ^Buffer($T)) {
	delete(buffer.cpu)

	for gpu in buffer.gpu_ring {
		gpu->release()
	}
}
