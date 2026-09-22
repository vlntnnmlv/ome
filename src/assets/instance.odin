package omeassets

import "base:builtin"
import "base:runtime"
import "core:log"
import "core:strings"

import "ome:gpu"
import "ome:handle_map"

Instance :: struct {
	device:        ^gpu.Device,
	fonts:         handle_map.Map(Font, FontHandle),
	atlases:       handle_map.Map(Atlas, AtlasHandle),
	texture_names: map[string]gpu.TextureHandle,
	atlas_names:   map[string]AtlasHandle,
	font_names:    map[string]FontHandle,
}

instance :: proc(renderer: ^gpu.Device) -> ^Instance {
	instance: ^Instance = new(Instance)

	font_map, fm_err := handle_map.make(Font, FontHandle)
	assert(fm_err == runtime.Allocator_Error.None)

	atlas_map, am_err := handle_map.make(Atlas, AtlasHandle)
	assert(am_err == runtime.Allocator_Error.None)

	instance.device = renderer
	instance.fonts = font_map
	instance.atlases = atlas_map

	instance.texture_names = make_map(map[string]gpu.TextureHandle)
	instance.atlas_names = make_map(map[string]AtlasHandle)
	instance.font_names = make_map(map[string]FontHandle)

	return instance
}

load_font :: proc(
	instance: ^Instance,
	path: string,
	name: string,
	sizes: []u32 = {},
) -> (
	FontHandle,
	FontError,
) {
	font_handle, err := handle_map.add(&instance.fonts, Font{})
	assert(err == runtime.Allocator_Error.None)

	font := handle_map.get(instance.fonts, font_handle)
	ferr := font_load(font, path, sizes)
	if ferr == FontError.None {
		if name not_in instance.font_names {
			instance.font_names[strings.clone(name)] = font_handle
		} else {
			log.warnf("Font with name '%s' already exists", name)
		}
	}
	return font_handle, ferr
}

get_font :: proc(instnace: ^Instance, handle: FontHandle) -> ^Font {
	return handle_map.get(instnace.fonts, handle)
}

font_by_name :: proc(instance: ^Instance, name: string) -> (FontHandle, bool) {
	handle, found := instance.font_names[name]
	return handle, found
}

load_atlas :: proc(
	instance: ^Instance,
	directory_path: string,
	name: string,
) -> (
	AtlasHandle,
	AtlasError,
) {
	atlas_handle, err := handle_map.add(&instance.atlases, Atlas{})
	assert(err == runtime.Allocator_Error.None)

	atlas := handle_map.get(instance.atlases, atlas_handle)

	aerr := atlas_load(atlas, instance.device.bind_table, directory_path, name)
	if aerr == AtlasError.None {
		if name not_in instance.atlas_names {
			instance.atlas_names[strings.clone(name)] = atlas_handle
		} else {
			log.warnf("Atlas with name '%s' already exists", name)
		}
	}
	return atlas_handle, aerr
}

get_atlas :: proc(instance: ^Instance, handle: AtlasHandle) -> ^Atlas {
	return handle_map.get(instance.atlases, handle)
}

atlas_by_name :: proc(instance: ^Instance, name: string) -> (AtlasHandle, bool) {
	handle, found := instance.atlas_names[name]
	return handle, found
}

load_texture :: proc(instance: ^Instance, path: string, name: string) -> gpu.TextureHandle {
	handle := gpu.texture_create(instance.device.bind_table, path, name)
	instance.texture_names[strings.clone(name)] = handle
	return handle
}

flush :: proc(instance: ^Instance) {
	iter := handle_map.make_iter(&instance.fonts)
	for font in handle_map.iter(&iter) {
		font_flush(font, instance.device.bind_table)
	}
}

destroy :: proc(instance: ^Instance) {
	for name, _ in instance.texture_names do builtin.delete(name)
	for name, _ in instance.atlas_names do builtin.delete(name)
	for name, _ in instance.font_names do builtin.delete(name)

	fiter := handle_map.make_iter(&instance.fonts)
	for font in handle_map.iter(&fiter) {
		font_destroy(font)
	}

	aiter := handle_map.make_iter(&instance.atlases)
	for atlas in handle_map.iter(&aiter) {
		atlas_destroy(atlas)
	}

	delete_map(instance.texture_names)
	delete_map(instance.atlas_names)
	delete_map(instance.font_names)

	handle_map.delete(&instance.fonts)
	handle_map.delete(&instance.atlases)
}
