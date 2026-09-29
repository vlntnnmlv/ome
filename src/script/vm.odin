package omescript

import "base:runtime"
import "core:c"
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

// Returns the message; does not log
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

// Returns the message; does not log
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
vm_run_chunk :: proc(
	vm: ^VM,
	data: []byte,
	chunk_name: string,
	allocator: mem.Allocator = context.allocator,
) -> (
	err: Error,
	message: string,
) {
	cname := strings.clone_to_cstring(chunk_name)

	status := LUA.L_loadbuffer(vm.state, raw_data(data), c.size_t(len(data)), cname, "t")
	if status != .OK {
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

vm_destroy :: proc(vm: ^VM) {
	if vm == nil {
		return
	}

	allocator := vm.ctx.allocator
	LUA.close(vm.state)
	free(vm, allocator)
}
