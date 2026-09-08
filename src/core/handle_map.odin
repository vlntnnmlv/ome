package ome

import "base:runtime"
import "core:mem"
import "core:mem/virtual"

Handle :: struct {
	idx: u32,
	gen: u32,
}

HandleMap :: struct($T: typeid, $HT: typeid) {
	items:        [dynamic]^T,
	items_arena:  virtual.Arena,
	unused_items: [dynamic]u32,
}

handle_map_make :: proc(
	$T: typeid,
	$HT: typeid,
	allocator: mem.Allocator = context.allocator,
) -> (
	handle_map: HandleMap(T, HT),
	err: runtime.Allocator_Error,
) {
	handle_map = HandleMap(T, HT) {
		items        = make([dynamic]^T, allocator),
		unused_items = make([dynamic]u32, allocator),
	}

	virtual.arena_init_growing(
		&handle_map.items_arena,
		uint(virtual.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE),
	) or_return

	return handle_map, nil
}

arena_initialized :: proc(arena: virtual.Arena) -> bool {
	return arena.curr_block != nil
}

handle_map_add :: proc(
	handle_map: ^HandleMap($T, $HT),
	value: T,
) -> (
	handle: HT,
	err: runtime.Allocator_Error,
) {
	if !arena_initialized(handle_map.items_arena) {
		handle_map^ = handle_map_make(T, HT) or_return
	}

	value := value

	if len(handle_map.unused_items) > 0 {
		reuse_index := pop(&handle_map.unused_items)
		reused := handle_map.items[reuse_index]
		gen := reused.handle.gen
		reused^ = value
		reused.handle.idx = u32(reuse_index)
		reused.handle.gen = gen + 1
		return reused.handle, nil
	}

	items_allocator := virtual.arena_allocator(&handle_map.items_arena)

	if len(handle_map.items) == 0 {
		zero_dummy := new(T, items_allocator) or_return
		append(&handle_map.items, zero_dummy)
	}

	new_item := new(T, items_allocator) or_return
	new_item^ = value
	new_item.handle.idx = u32(len(handle_map.items))
	new_item.handle.gen = 1
	append(&handle_map.items, new_item)
	return new_item.handle, nil
}

handle_map_get :: proc(m: HandleMap($T, $HT), h: HT) -> ^T {
	if h.idx <= 0 || h.idx >= u32(len(m.items)) {
		return nil
	}

	if item := m.items[h.idx]; item.handle == h {
		return item
	}

	return nil
}

handle_map_remove :: proc(m: ^HandleMap($T, $HT), h: HT) {
	if h.idx <= 0 || h.idx >= u32(builtin.len(m.items)) {
		return
	}

	if item := m.items[h.idx]; item.handle == h {
		append(&m.unused_items, h.idx)
		item.handle.idx = 0
	}
}

valid :: proc(m: HandleMap($T, $HT), h: HT) -> bool {
	return get(m, h) != nil
}

handle_map_delete :: proc(handle_map: ^HandleMap($T, $HT)) {
	virtual.arena_destroy(&handle_map.items_arena)
	delete(handle_map.items)
	delete(handle_map.unused_items)
}
