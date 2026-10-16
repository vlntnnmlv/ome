package omeui

import "base:intrinsics"
import "core:encoding/json"
import "core:io"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strings"

spec_marshaller :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	spec := (cast(^Spec)v.data)^

	switch s in spec {
	case PanelSpec:
		json.marshal_to_writer(w, s, opt) or_return
	case ButtonSpec:
		json.marshal_to_writer(w, s, opt) or_return
	case TextSpec:
		json.marshal_to_writer(w, s, opt) or_return
	case ImageSpec:
		json.marshal_to_writer(w, s, opt) or_return
	}

	return json.Marshal_Data_Error.None
}

handle_marshaller :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	return nil
}

json_save :: proc(data: any, filename: string) -> bool {
	info := type_info_of(data.id)
	if !reflect.is_struct(info) {
		return false
	}

	filename_with_extension := strings.concatenate({filename, ".json"}, context.temp_allocator)

	file, err := os.open(filename_with_extension, {.Read, .Write, .Trunc, .Create})
	if err != nil {
		log.errorf("json/serialization: couldn't open file '%s'", filename_with_extension)
	}

	marshallers := new(map[typeid]json.User_Marshaler)
	defer free(marshallers)

	json.set_user_marshalers(marshallers)
	reg_err := json.register_user_marshaler(Spec, spec_marshaller)
	assert(reg_err == .None)
	// reg_err = json.register_user_marshaler(handle_map.Handle, spec_marshaller)
	reg_err = json.register_user_marshaler(any, spec_marshaller)
	assert(reg_err == .None)

	json_data, json_err := json.marshal(
		data,
		json.Marshal_Options{pretty = true, spec = .JSON5, use_enum_names = true},
	)

	if json_err != nil {
		log.errorf("json/serialization: couldn't serialize data to json")
		return false
	}

	os.write(file, json_data)

	return true
}

json_string :: proc(
	obj: json.Object,
	key: string,
	fallback: string = "",
) -> (
	str: string,
	ok: bool,
) {
	str, ok = obj[key].(json.String)
	if !ok {
		str = fallback
		return
	}

	return
}

json_number :: proc(
	obj: json.Object,
	key: string,
	$T: typeid,
	fallback: T,
) -> (
	f: T,
	ok: bool,
) where intrinsics.type_is_numeric(T) {
	value: f64
	value, ok = obj[key].(json.Float)
	if !ok {
		f = fallback
		return
	}

	f = T(value)
	return
}

json_numbers :: proc(obj: json.Object, key: string, $T: typeid, out: []T) -> bool {
	arr, ok := obj[key].(json.Array)
	if !ok {
		return false
	}

	for v, i in arr {
		n, is_number := v.(json.Float)
		if !is_number {
			return false
		}

		out[i] = T(n)
	}

	return true
}

json_enum :: proc(obj: json.Object, key: string, fallback: $T) -> (e: T, ok: bool) {
	e_str: string
	e_str, ok = obj[key].(json.String)
	if !ok {
		e = fallback
		return
	}

	e, ok = reflect.enum_from_name(T, strings.to_ada_case(e_str, context.temp_allocator))
	if !ok {
		e = fallback
		return
	}

	return
}
