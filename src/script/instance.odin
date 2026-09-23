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
}

Ref :: distinct i32
NO_REF :: Ref(lua.NOREF)

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

@(private)
push_module_table :: proc(instance: ^Instance, module: Ref, table_key: cstring) -> bool {
	lua.rawgeti(instance.state, lua.REGISTRYINDEX, lua.Integer(module))
	lua.getfield(instance.state, -1, table_key)
	return lua.istable(instance.state, -1)
}

call_action :: proc(instance: ^Instance, module: Ref, name: string) -> (Error, string) {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	push_module_table(instance, module, "actions")

	cname := strings.clone_to_cstring(name, context.temp_allocator)
	lua.getfield(L, -1, cname)
	if !lua.isfunction(L, -1) do return .Runtime, fmt.tprintf("no action '%s'", name)

	lua.getfield(L, -3, "model")
	if rc := lua.pcall(L, 1, 0, 0); rc != 0 {
		return status_to_error(lua.Status(rc)), pop_message(instance, context.temp_allocator)
	}
	return .None, ""
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

@(private)
push_field :: proc(instance: ^Instance, index: i32, key: string) -> bool {
	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(instance.state, c.int(index), ckey)
	if !lua.istable(instance.state, -1) {
		lua.pop(instance.state, 1)
		return false
	}
	return true
}

get_string :: proc(
	instance: ^Instance,
	module: Ref,
	table_key: cstring,
	key: string,
	allocator := context.temp_allocator,
) -> (
	string,
	bool,
) {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	push_module_table(instance, module, table_key)

	ckey := strings.clone_to_cstring(key, context.temp_allocator)
	lua.getfield(L, -1, ckey) // module, tbl, value
	if lua.isnil(L, -1) do return "", false

	s := lua.L_tostring(L, -1) // module, tbl, value, str
	return strings.clone(string(s), allocator), true
}

get_numbers :: proc(
	instance: ^Instance,
	module: Ref,
	table_key: cstring,
	key: string,
	out: []f32,
) -> bool {
	L := instance.state
	top := lua.gettop(L)
	defer lua.settop(L, top)

	push_module_table(instance, module, table_key)

	return field_numbers(instance, -1, key, out)
}

@(private)
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

destroy :: proc(instance: ^Instance) {
	if instance == nil do return

	allocator := instance.ctx.allocator
	lua.close(instance.state)
	free(instance, allocator)
}
