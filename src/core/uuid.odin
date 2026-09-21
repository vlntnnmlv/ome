package omecore

import "core:encoding/uuid"
import "core:mem"

uuid_create :: proc(allocator: mem.Allocator) -> string {
	id := uuid.generate_v4()
	buf: []byte = make([]byte, 36, allocator)
	str := uuid.to_string_buffer(id, buf[:])
	return str
}
