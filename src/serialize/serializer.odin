package omeserialize

import "base:runtime"
import "core:encoding/json"
import "core:io"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import "core:testing"

Error :: enum {
	None,
	Unsupported_Type,
	Type_Mismatch,
	Unknown_Variant,
	Unknown_Enum_Name,
	Out_Of_Memory,
}

encode :: proc(src: any, allocator: mem.Allocator) -> (value: json.Value, err: Error) {
	if src.data == nil {
		value = json.Null{}
		err = .None
		return
	}

	type_info := runtime.type_info_base(type_info_of(src.id))

	err = .None
	value = nil

	#partial switch info in type_info.variant {
	case runtime.Type_Info_Integer:
		i, _ := reflect.as_int(src)
		value = json.Integer(i)
	case runtime.Type_Info_Float:
		f, _ := reflect.as_f64(src)
		value = json.Float(f)
	case runtime.Type_Info_Boolean:
		b, _ := reflect.as_bool(src)
		value = json.Boolean(b)
	case runtime.Type_Info_String:
		if info.is_cstring {
			err = .Unsupported_Type
			return
		}

		s, _ := reflect.as_string(src)
		value = json.String(s)
	case runtime.Type_Info_Enum:
		name, ok := reflect.enum_name_from_value_any(src)
		if !ok {
			err = .Unknown_Enum_Name
			return
		}
		value = json.String(name)
	case runtime.Type_Info_Struct:
		log.info("Struct!")
		if .raw_union in info.flags {
			err = .Unsupported_Type
			return
		}

		obj := make(json.Object, allocator)
		for i in 0 ..< int(info.field_count) {
			field := any{rawptr(uintptr(src.data) + info.offsets[i]), info.types[i].id}
			log.info("field:", field)
			field_value := encode(field, allocator) or_return

			// flatten the unnmaed using: `using _: T`
			if info.usings[i] && info.names[i] == "_" {
				for key, x in field_value.(json.Object) {
					obj[key] = x
				}
				continue
			}

			obj[info.names[i]] = field_value
		}
		value = obj
	case:
		err = .Unsupported_Type
	}

	return
}


@(private)
write_int :: proc(dst: rawptr, size: int, n: i64) {
	switch size {
	case 1:
		(^u8)(dst)^ = u8(n)
	case 2:
		(^u16)(dst)^ = u16(n)
	case 4:
		(^u32)(dst)^ = u32(n)
	case 8:
		(^u64)(dst)^ = u64(n)
	}
}

@(private)
write_float :: proc(dst: rawptr, size: int, f: f64) {
	switch size {
	case 2:
		(^f16)(dst)^ = f16(f)
	case 4:
		(^f32)(dst)^ = f32(f)
	case 8:
		(^f64)(dst)^ = f
	}
}

decode :: proc(value: json.Value, dst: any, allocator: mem.Allocator) -> (err: Error) {
	type_info := runtime.type_info_base(type_info_of(dst.id))

	err = .None
	#partial switch info in type_info.variant {
	case runtime.Type_Info_Integer:
		if info.endianness != .Platform {
			err = .Unsupported_Type
			return
		}
		n: i64
		#partial switch v in value {
		case json.Integer:
			n = v
		case json.Float:
			n = i64(v)
		case:
			err = .Type_Mismatch
			return
		}
		write_int(dst.data, type_info.size, n)
		return
	case runtime.Type_Info_Float:
		f: f64
		#partial switch v in value {
		case json.Float:
			f = v
		case json.Integer:
			f = f64(v)
		case:
			err = .Type_Mismatch
			return
		}
		write_float(dst.data, type_info.size, f)
		return
	case runtime.Type_Info_Boolean:
		b, ok := value.(json.Boolean)
		if !ok {
			err = .Type_Mismatch
			return
		}
		write_int(dst.data, type_info.size, 1 if b else 0)
		return
	case runtime.Type_Info_String:
		if info.is_cstring {
			err = .Unsupported_Type
			return
		}
		s, ok := value.(json.String)
		if !ok {
			err = .Type_Mismatch
			return
		}
		(^string)(dst.data)^ = strings.clone(s, allocator)
	case runtime.Type_Info_Enum:
		name, ok := value.(json.String)
		if !ok {
			err = .Type_Mismatch
			return
		}
		n, found := reflect.enum_from_name_any(dst.id, name)
		if !found {
			err = .Unknown_Enum_Name
			return
		}
		write_int(dst.data, type_info.size, i64(n))
	case runtime.Type_Info_Struct:
		if .raw_union in info.flags {
			err = .Unsupported_Type
			return
		}

		obj, ok := value.(json.Object)
		if !ok {
			err = .Type_Mismatch
			return
		}

		for i in 0 ..< int(info.field_count) {
			field := any{rawptr(uintptr(dst.data) + info.offsets[i]), info.types[i].id}

			if info.usings[i] && info.names[i] == "_" {
				decode(obj, field, allocator) or_return
				continue
			}

			sub, has := obj[info.names[i]]
			if !has {
				continue
			}
			decode(sub, field, allocator) or_return
		}
	case:
		err = .Unsupported_Type
	}

	return
}

SERIALIZER_OPTIONS :: json.Marshal_Options {
	spec             = .JSON5,
	pretty           = true,
	use_spaces       = true,
	use_enum_names   = true,
	sort_maps_by_key = true,
}

serialize :: proc(data: any, name: string) -> bool {
	filename := strings.concatenate({name, ".json"}, context.temp_allocator)
	path, _ := filepath.join({"assets", "data", filename}, context.temp_allocator)
	os.make_directory(filepath.dir(path))

	file, err := os.open(path, {.Read, .Write, .Trunc, .Create})
	if err != nil {
		log.errorf("serialization: couldn't open file")
		return false
	}
	defer os.close(file)

	value, enc_err := encode(data, context.temp_allocator)
	if enc_err != .None {
		log.errorf("serialization: encoding failed: %v", enc_err)
		return false
	}

	json_data, json_err := json.marshal(value, SERIALIZER_OPTIONS, context.temp_allocator)
	if json_err != nil {
		log.errorf("serialization: couldn't convert data to json")
		return false
	}

	os.write(file, json_data)
	return true
}

deserialize :: proc(name: string, data: ^$T) -> bool {
	filename := strings.concatenate({name, ".json"}, context.temp_allocator)
	path, _ := filepath.join({"assets", "data", filename}, context.temp_allocator)

	file, err := os.open(path, {.Read})
	if err != nil {
		log.errorf("serialization: couldn't open file '%s'", path)
		return false
	}
	defer os.close(file)

	json_data, read_err := os.read_entire_file(file, context.temp_allocator)
	if read_err != nil {
		log.errorf("serialization: couldn't read file '%s'", path)
		return false
	}

	json_value, parse_err := json.parse(json_data, .JSON5, true, context.temp_allocator)
	if parse_err != .None {
		log.errorf("serialization: couldn't convert data to json")
		return false
	}

	dec_err := decode(json_value, any{rawptr(data), typeid_of(T)}, context.allocator)
	return true
}

CoolEnum :: enum {
	Smudge,
	Fudge,
	Budge,
}

IndexEnum :: enum {
	X,
	Y,
}

Number :: distinct f32
BetterNumber :: distinct f32
Span :: struct {
	start, end: f32,
}
CoolUnion :: union {
	Number,
	BetterNumber,
	Span,
}

BaseString :: struct {
	base_msg: string,
}
String :: struct {
	using _: BaseString,
	msg:     string,
}
BetterString :: struct {
	using _:    BaseString,
	better_msg: string,
}
NotCoolUnion :: union {
	BaseString,
	String,
	BetterString,
}

InnerStruct :: struct {
	s: string,
}

CoolStruct :: struct {
	i:     int,
	s:     string,
	f:     f32,
	fl:    f64,
	e:     CoolEnum,
	inner: InnerStruct,
	// earr:  [IndexEnum]f32,
	// u:     CoolUnion,
	// nu:    NotCoolUnion,
}

@(test)
primitive :: proc(t: ^testing.T) {
	x: int = 64
	x2: i32 = 65
	x3: u8 = 66
	x4: f64 = 67
	x5: f32 = 68
	x6: string = "69"

	serialize(x, "x")
	serialize(x2, "x2")
	serialize(x3, "x3")
	serialize(x4, "x4")
	serialize(x5, "x5")
	serialize(x6, "x6")

	y: int
	y2: i32
	y3: u8
	y4: f64
	y5: f32
	y6: string
	defer delete(y6)

	deserialize("x", &y)
	deserialize("x2", &y2)
	deserialize("x3", &y3)
	deserialize("x4", &y4)
	deserialize("x5", &y5)
	deserialize("x6", &y6)

	testing.expect(t, x == y)
	testing.expect(t, x2 == y2)
	testing.expect(t, x3 == y3)
	testing.expect(t, x4 == y4)
	testing.expect(t, x5 == y5)
	testing.expect(t, x6 == y6)

	// testing.expect(t, a.e == a2.e, "CoolEnum values mismatch")
	// testing.expect(t, a.inner == a2.inner, "InnerStruct values mismatch")
	// testing.expect(t, a.u == a2.u, "CoolUnion values mismatch")
	// testing.expect(t, a.f == a2.f, "f32 values mismatch")
	// testing.expect(t, a.fl == a2.fl, "f64 values mismatch")
	// testing.expect(t, a.s == a2.s, "string values mismatch")
	// testing.expect(t, a.i == a2.i, "int values mismatch")
}

@(test)
enums :: proc(t: ^testing.T) {
	e: CoolEnum = .Fudge

	serialize(e, "e")

	e2: CoolEnum

	deserialize("e", &e2)

	testing.expect(t, e == e2)
}

@(test)
structs :: proc(t: ^testing.T) {
	s: CoolStruct = {64, "Hi", 3.3, 3.33333, .Fudge, {"inner"}}

	serialize(s, "s")

	s2: CoolStruct

	deserialize("s", &s2)
	defer delete(s2.s)
	defer delete(s2.inner.s)

	testing.expect(t, s == s2)
}
