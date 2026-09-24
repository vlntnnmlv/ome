package omescript

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

import lua "vendor:lua/5.4"

Error :: enum {
	None = 0,
	File_Not_Found,
	Syntax,
	Runtime,
	Memory,
	Missing,
}

Ref :: distinct i32
NO_REF :: Ref(lua.NOREF)

call :: proc(
	instance: ^Instance,
	module: Ref,
	table_key: cstring,
	name: cstring,
	args: ..f64,
) -> (
	Error,
	string,
) {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(module))
	module_idx := lua.gettop(L)

	container := module_idx
	if table_key != nil {
		lua.getfield(L, module_idx, table_key)
		if !lua.istable(L, -1) {
			return .Missing, fmt.tprintf("module has no '%s' table", table_key)
		}
		container = lua.gettop(L)
	}

	lua.pushcfunction(L, traceback)
	handler := lua.gettop(L)

	lua.getfield(L, container, name)
	if !lua.isfunction(L, -1) do return .Missing, fmt.tprintf("no function '%s'", name)

	lua.getfield(L, module_idx, "model")
	for a in args do lua.pushnumber(L, lua.Number(a))

	if rc := lua.pcall(L, c.int(1 + len(args)), 0, handler); rc != 0 {
		return status_to_error(lua.Status(rc)), pop_message(instance, context.temp_allocator)
	}
	return .None, ""
}

@(private)
traceback :: proc "c" (L: ^lua.State) -> c.int {
	lua.L_traceback(L, L, lua.tostring(L, 1), 1)
	return 1
}

@(private)
ref_top :: proc(instance: ^Instance) -> Ref {
	return Ref(lua.L_ref(instance.state, lua.REGISTRYINDEX))
}

unref :: proc(instance: ^Instance, ref: Ref) {
	if ref == NO_REF do return
	lua.L_unref(instance.state, lua.REGISTRYINDEX, c.int(ref))
}

load_module :: proc(instance: ^Instance, path: string) -> (Ref, bool) {
	if err, msg := run_file(instance, path); err != .None {
		log.errorf("script: %s: %v: %s", path, err, msg)
		return NO_REF, false
	}
	if !lua.istable(instance.state, -1) {
		log.errorf("script: %s must return a table", path)
		clear_stack(instance)
		return NO_REF, false
	}
	return ref_top(instance), true
}

Instance :: struct {
	state: ^lua.State,
	ctx:   runtime.Context,
}

instance :: proc(allocator: mem.Allocator = context.allocator) -> (^Instance, bool) {
	instance := new(Instance, allocator)
	instance.ctx = context
	instance.ctx.allocator = allocator

	instance.state = lua.newstate(lua_alloc, &instance.ctx)
	if instance.state == nil {
		free(instance, allocator)
		log.error("Couldn't create Lua state")
		return nil, false
	}

	lua.L_openlibs(instance.state)
	return instance, true
}

@(private)
lua_alloc :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> rawptr {
	context = (^runtime.Context)(ud)^

	if nsize == 0 {
		if ptr != nil do runtime.mem_free(ptr)
		return nil
	}

	if ptr == nil {
		data, err := runtime.mem_alloc(int(nsize))
		return raw_data(data) if err == .None else nil
	}

	data, err := runtime.mem_resize(ptr, int(osize), int(nsize))
	return raw_data(data) if err == .None else nil
}

@(private)
array_len :: proc(instance: ^Instance, index: i32) -> int {
	return int(lua.rawlen(instance.state, c.int(index)))
}

@(private)
pop :: proc(instance: ^Instance, n: int = 1) {
	lua.pop(instance.state, c.int(n))
}

get_string :: proc(
	instance: ^Instance,
	module: Ref,
	path: string,
	allocator := context.temp_allocator,
) -> (
	string,
	Error,
	string,
) {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	if err, msg := push_bound(instance, module, path); err != .None do return "", err, msg
	s := lua.L_tostring(L, -1)

	return strings.clone(string(s), allocator), .None, ""
}

get_numbers :: proc(
	instance: ^Instance,
	module: Ref,
	path: string,
	out: []f32,
) -> (
	Error,
	string,
) {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	if err, msg := push_bound(instance, module, path); err != .None do return err, msg
	if !lua.istable(L, -1) || array_len(instance, -1) < len(out) do return .Missing, ""

	for i in 0 ..< len(out) {
		lua.rawgeti(L, -1, lua.Integer(i + 1))
		is_number: b32
		n := lua.tonumber(L, -1, &is_number)
		lua.pop(L, 1)
		if !is_number do return .Missing, ""
		out[i] = f32(n)
	}
	return .None, ""
}

@(private)
run_file :: proc(
	instance: ^Instance,
	path: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	err: Error,
	message: string,
) {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	if status := lua.L_loadfile(instance.state, cpath); status != .OK {
		return status_to_error(status), pop_message(instance, allocator)
	}

	if rc := lua.pcall(instance.state, 0, 1, 0); rc != 0 {
		return status_to_error(lua.Status(rc)), pop_message(instance, allocator)
	}

	return .None, ""
}

@(private)
clear_stack :: proc(instance: ^Instance) {
	lua.settop(instance.state, 0)
}

@(private)
pop_message :: proc(instance: ^Instance, allocator: mem.Allocator) -> string {
	out := strings.clone(string(lua.tostring(instance.state, -1)), allocator)
	lua.pop(instance.state, 1)
	return out
}

@(private)
status_to_error :: proc(status: lua.Status) -> Error {
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
resolve :: proc "c" (L: ^lua.State) -> c.int {
	lua.getfield(L, 1, "computed")
	if lua.istable(L, -1) {
		lua.pushvalue(L, 2)
		lua.gettable(L, -2)
		if lua.isfunction(L, -1) {
			lua.getfield(L, 1, "model")
			lua.call(L, 1, 1)
			return 1
		}
		lua.pop(L, 1)
	}
	lua.pop(L, 1)

	lua.getfield(L, 1, "model")
	if !lua.istable(L, -1) do return 0 // pcall pads the missing result with nil
	lua.pushvalue(L, 2)
	lua.gettable(L, -2)
	return 1
}

@(private)
push_bound :: proc(instance: ^Instance, module: Ref, path: string) -> (Error, string) {
	L := instance.state
	lua.pushcfunction(L, traceback)
	handler := lua.gettop(L)

	lua.pushcfunction(L, resolve)
	lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(module))
	lua.pushstring(L, strings.clone_to_cstring(path, context.temp_allocator))

	if rc := lua.pcall(L, 2, 1, handler); rc != 0 {
		return status_to_error(lua.Status(rc)), pop_message(instance, context.temp_allocator)
	}
	if lua.isnil(L, -1) do return .Missing, ""
	return .None, ""
}

destroy :: proc(instance: ^Instance) {
	if instance == nil do return

	allocator := instance.ctx.allocator
	lua.close(instance.state)
	free(instance, allocator)
}
