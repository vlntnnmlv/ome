package omescript

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

import LUA "vendor:lua/5.4"

Error :: enum {
	None = 0,
	File_Not_Found,
	Syntax,
	Runtime,
	Memory,
	Missing,
}

Ref :: distinct i32
NO_REF :: Ref(LUA.NOREF)

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
			return .Missing, fmt.tprintf("module has no '%s' table", table_key)
		}
		container = LUA.gettop(L)
	}

	LUA.pushcfunction(L, traceback)
	handler := LUA.gettop(L)

	LUA.getfield(L, container, name)
	if !LUA.isfunction(L, -1) {
		return .Missing, fmt.tprintf("no function '%s'", name)
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
traceback :: proc "c" (L: ^LUA.State) -> c.int {
	LUA.L_traceback(L, L, LUA.tostring(L, 1), 1)
	return 1
}

@(private)
vm_ref_top :: proc(vm: ^VM) -> Ref {
	return Ref(LUA.L_ref(vm.state, LUA.REGISTRYINDEX))
}

vm_unref :: proc(vm: ^VM, ref: Ref) {
	if ref == NO_REF {
		return
	}

	LUA.L_unref(vm.state, LUA.REGISTRYINDEX, c.int(ref))
}

vm_load_module :: proc(vm: ^VM, path: string) -> (Ref, bool) {
	if err, msg := vm_run_file(vm, path); err != nil {
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

VM :: struct {
	state: ^LUA.State,
	ctx:   runtime.Context,
}

vm_create :: proc(allocator: mem.Allocator = context.allocator) -> (^VM, bool) {
	vm := new(VM, allocator)
	vm.ctx = context
	vm.ctx.allocator = allocator

	vm.state = LUA.newstate(lua_alloc, &vm.ctx)
	if vm.state == nil {
		free(vm, allocator)
		log.error("script: couldn't create Lua state")
		return nil, false
	}

	LUA.L_openlibs(vm.state)
	return vm, true
}

@(private)
lua_alloc :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> rawptr {
	context = (^runtime.Context)(ud)^

	if nsize == 0 {
		if ptr != nil {
			runtime.mem_free(ptr)
		}
		return nil
	}

	if ptr == nil {
		data, err := runtime.mem_alloc(int(nsize))
		if err == .None {
			return raw_data(data)
		}

		return nil
	}

	data, err := runtime.mem_resize(ptr, int(osize), int(nsize))
	if err == .None {
		return raw_data(data)
	}

	return nil
}

@(private)
vm_array_len :: proc(vm: ^VM, index: i32) -> int {
	return int(LUA.rawlen(vm.state, c.int(index)))
}

@(private)
vm_pop :: proc(vm: ^VM, n: int = 1) {
	LUA.pop(vm.state, c.int(n))
}

vm_get_string :: proc(
	vm: ^VM,
	module_ref: Ref,
	path: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	string,
	Error,
	string,
) {
	L := vm.state
	top := LUA.gettop(L)
	defer LUA.settop(L, top)

	if err, msg := vm_push_bound(vm, module_ref, path); err != nil {
		return "", err, msg
	}
	s := LUA.L_tostring(L, -1)

	return strings.clone(string(s), allocator), .None, ""
}

vm_get_numbers :: proc(vm: ^VM, module_ref: Ref, path: string, out: []f32) -> (Error, string) {
	L := vm.state
	top := LUA.gettop(L)
	defer LUA.settop(L, top)

	if err, msg := vm_push_bound(vm, module_ref, path); err != nil {
		return err, msg
	}
	if !LUA.istable(L, -1) || vm_array_len(vm, -1) < len(out) {
		return .Missing, ""
	}

	for i in 0 ..< len(out) {
		LUA.rawgeti(L, -1, LUA.Integer(i + 1))
		is_number: b32
		n := LUA.tonumber(L, -1, &is_number)
		LUA.pop(L, 1)
		if !is_number {
			return .Missing, ""
		}

		out[i] = f32(n)
	}
	return .None, ""
}

@(private)
vm_run_file :: proc(
	vm: ^VM,
	path: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	err: Error,
	message: string,
) {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	if status := LUA.L_loadfile(vm.state, cpath); status != .OK {
		return status_to_error(status), vm_pop_message(vm, allocator)
	}

	if rc := LUA.pcall(vm.state, 0, 1, 0); rc != 0 {
		return status_to_error(LUA.Status(rc)), vm_pop_message(vm, allocator)
	}

	return .None, ""
}

@(private)
vm_clear_stack :: proc(vm: ^VM) {
	LUA.settop(vm.state, 0)
}

@(private)
vm_pop_message :: proc(vm: ^VM, allocator: mem.Allocator) -> string {
	out := strings.clone(string(LUA.tostring(vm.state, -1)), allocator)
	LUA.pop(vm.state, 1)
	return out
}

@(private)
status_to_error :: proc(status: LUA.Status) -> Error {
	#partial switch status {
	case .OK:
		return .None
	case .ERRSYNTAX:
		return .Syntax
	case .ERRFILE:
		return .File_Not_Found
	case .ERRMEM:
		return .Memory
	}
	return .Runtime
}

@(private)
resolve :: proc "c" (L: ^LUA.State) -> c.int {
	LUA.getfield(L, 1, "computed")
	if LUA.istable(L, -1) {
		LUA.pushvalue(L, 2)
		LUA.gettable(L, -2)
		if LUA.isfunction(L, -1) {
			LUA.getfield(L, 1, "model")
			LUA.call(L, 1, 1)
			return 1
		}
		LUA.pop(L, 1)
	}
	LUA.pop(L, 1)

	LUA.getfield(L, 1, "model")
	if !LUA.istable(L, -1) {
		return 0 // pcall pads the missing result with nil
	}

	LUA.pushvalue(L, 2)
	LUA.gettable(L, -2)
	return 1
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

vm_destroy :: proc(vm: ^VM) {
	if vm == nil {
		return
	}

	allocator := vm.ctx.allocator
	LUA.close(vm.state)
	free(vm, allocator)
}
