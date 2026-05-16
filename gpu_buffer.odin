#+private

package ome

import "core:mem"
import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"

INITIAL_BUFFER_SIZE :: 1024

GPUBuffer :: struct($T: typeid) {
	cpu:    [dynamic]T,
	gpu:    ^MTL.Buffer,
	device: ^MTL.Device,
	cap:    int,
}

gpu_buffer_create :: proc($T: typeid, device: ^MTL.Device) -> GPUBuffer(T) {
	buffer: GPUBuffer(T)
	buffer.device = device
	buffer.cpu = make([dynamic]T, 0, INITIAL_BUFFER_SIZE)
	buffer.gpu = buffer.device->newBufferWithLength(INITIAL_BUFFER_SIZE * size_of(T), {})
	buffer.cap = INITIAL_BUFFER_SIZE

	return buffer
}

gpu_buffer_append :: proc(buffer: ^GPUBuffer($T), data: []T) {
	if len(buffer.cpu) + len(data) > buffer.cap {
		buffer.cap *= 2

		// cpu
		reserve(&buffer.cpu, buffer.cap)

		// gpu
		old_gpu := buffer.gpu
		buffer.gpu = buffer.device->newBufferWithLength(
			cast(NS.UInteger)buffer.cap * size_of(T),
			{},
		)
		mem.copy(
			raw_data(buffer.gpu->contents()),
			raw_data(old_gpu->contents()),
			len(buffer.cpu) * size_of(T),
		)

		old_gpu->release()
	}

	append(&buffer.cpu, ..data)
}

gpu_buffer_clear :: proc(buffer_managed: ^GPUBuffer($T)) {
	clear(&buffer_managed.cpu)
}

gpu_buffer_submit :: proc(buffer_managed: ^GPUBuffer($T)) {
	contents := buffer_managed.gpu->contents()
	mem.copy(
		raw_data(contents),
		raw_data(buffer_managed.cpu),
		len(buffer_managed.cpu) * size_of(T),
	)
}
