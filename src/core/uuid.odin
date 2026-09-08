package ome

import "core:encoding/uuid"
import "core:mem"

UUID :: struct {
	uuid: string,
}

uuid_make :: proc(allocator: mem.Allocator) -> UUID {
	id := uuid.generate_v4()
	buf: []byte = make([]byte, 36, allocator)
	str := uuid.to_string_buffer(id, buf[:])
	return UUID{str}
}

uuid_delete :: proc(uuid: ^UUID, allocator: mem.Allocator) {
	delete(uuid.uuid, allocator)
}
