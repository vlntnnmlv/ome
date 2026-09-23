package omescript

import "base:runtime"
import "core:c"
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

abs_index :: proc(instance: ^Instance, index: i32) -> i32 {
	if index > 0 do return index
	return i32(lua.gettop(instance.state)) + index + 1
}

is_table :: proc(instance: ^Instance, index: i32) -> bool {
	return lua.istable(instance.state, c.int(index))
}

array_len :: proc(instance: ^Instance, index: i32) -> int {
	return int(lua.rawlen(instance.state, c.int(index)))
}

pop :: proc(instance: ^Instance, n: int = 1) {
	lua.pop(instance.state, c.int(n))
}

push_field :: proc(instance: ^Instance, index: i32, key: string) -> bool {
	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(instance.state, c.int(index), ckey)
	if !lua.istable(instance.state, -1) {
		lua.pop(instance.state, 1)
		return false
	}
	return true
}

push_index :: proc(instance: ^Instance, index: i32, i: int) -> bool {
	lua.rawgeti(instance.state, c.int(index), lua.Integer(i))
	if !lua.istable(instance.state, -1) {
		lua.pop(instance.state, 1)
		return false
	}
	return true
}

field_number :: proc(
	instance: ^Instance,
	index: i32,
	key: string,
	fallback: f32 = 0,
) -> (
	f32,
	bool,
) {
	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(instance.state, c.int(index), ckey)
	defer lua.pop(instance.state, 1)

	is_number: b32
	n := lua.tonumber(instance.state, -1, &is_number)
	if !is_number do return fallback, false
	return f32(n), true
}

field_string :: proc(
	instance: ^Instance,
	index: i32,
	key: string,
	fallback: string = "",
	allocator: mem.Allocator = context.allocator,
) -> (
	string,
	bool,
) {
	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(instance.state, c.int(index), ckey)
	defer lua.pop(instance.state, 1)

	if lua.type(instance.state, -1) != .STRING do return fallback, false
	return strings.clone(string(lua.tostring(instance.state, -1)), allocator), true
}

field_bool :: proc(
	instance: ^Instance,
	index: i32,
	key: string,
	fallback: bool = false,
) -> (
	bool,
	bool,
) {
	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(instance.state, c.int(index), ckey)
	defer lua.pop(instance.state, 1)

	if lua.type(instance.state, -1) != .BOOLEAN do return fallback, false
	return bool(lua.toboolean(instance.state, -1)), true
}

field_numbers :: proc(instance: ^Instance, index: i32, key: string, out: []f32) -> bool {
	if !push_field(instance, index, key) do return false
	defer lua.pop(instance.state, 1)

	if array_len(instance, -1) < len(out) do return false

	for i in 0 ..< len(out) {
		lua.rawgeti(instance.state, -1, lua.Integer(i + 1))
		is_number: b32
		n := lua.tonumber(instance.state, -1, &is_number)
		lua.pop(instance.state, 1)
		if !is_number do return false
		out[i] = f32(n)
	}
	return true
}

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

run_string :: proc(
	instance: ^Instance,
	source: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	err: Error,
	message: string,
) {
	csource := strings.clone_to_cstring(source, context.temp_allocator)

	if status := lua.L_loadstring(instance.state, csource); status != .OK {
		return status_to_error(status), pop_message(instance, allocator)
	}

	if rc := lua.pcall(instance.state, 0, 1, 0); rc != 0 {
		return status_to_error(lua.Status(rc)), pop_message(instance, allocator)
	}

	return .None, ""
}

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

destroy :: proc(instance: ^Instance) {
	if instance == nil do return

	allocator := instance.ctx.allocator
	lua.close(instance.state)
	free(instance, allocator)
}
