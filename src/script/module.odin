package omescript

import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"

import LUA "vendor:lua/5.4"

vm_load_module :: proc(vm: ^VM, data: []byte, path: string) -> (Ref, bool) {
	chunk_name := fmt.tprintf("@%s", path)
	if err, msg := vm_run_chunk(vm, data, chunk_name); err != nil {
		log.errorf("script: %s: %v: %s", path, err, msg)
		return NO_REF, false
	}
	if !LUA.istable(vm.state, -1) {
		log.errorf("script: %s must return a table", path)
		vm_clear_stack(vm)
		return NO_REF, false
	}
	return vm_ref_top(vm), true
}

// Returns the message; does not log
vm_call :: proc(
	vm: ^VM,
	module_ref: Ref,
	table_key: cstring,
	name: cstring,
	args: ..f64,
) -> (
	Error,
	string,
) {
	L := vm.state
	top := LUA.gettop(L)
	defer LUA.settop(L, top)

	LUA.rawgeti(L, LUA.REGISTRYINDEX, LUA.Integer(module_ref))
	module_idx := LUA.gettop(L)

	container := module_idx
	if table_key != nil {
		LUA.getfield(L, module_idx, table_key)
		if !LUA.istable(L, -1) {
			return .Missing, fmt.tprintf("script/module: module has no '%s' table", table_key)
		}
		container = LUA.gettop(L)
	}

	LUA.pushcfunction(L, traceback)
	handler := LUA.gettop(L)

	LUA.getfield(L, container, name)
	if !LUA.isfunction(L, -1) {
		return .Missing, fmt.tprintf("script/module: no function '%s'", name)
	}

	LUA.getfield(L, module_idx, "model")
	for a in args {
		LUA.pushnumber(L, LUA.Number(a))
	}

	if rc := LUA.pcall(L, c.int(1 + len(args)), 0, handler); rc != 0 {
		return status_to_error(LUA.Status(rc)), vm_pop_message(vm, context.temp_allocator)
	}
	return .None, ""
}

@(private)
vm_push_bound :: proc(vm: ^VM, module_ref: Ref, path: string) -> (Error, string) {
	L := vm.state
	LUA.pushcfunction(L, traceback)
	handler := LUA.gettop(L)

	LUA.pushcfunction(L, resolve)
	LUA.rawgeti(L, LUA.REGISTRYINDEX, LUA.Integer(module_ref))
	LUA.pushstring(L, strings.clone_to_cstring(path, context.temp_allocator))

	if rc := LUA.pcall(L, 2, 1, handler); rc != 0 {
		return status_to_error(LUA.Status(rc)), vm_pop_message(vm, context.temp_allocator)
	}
	if LUA.isnil(L, -1) {
		return .Missing, ""
	}
	return .None, ""
}
