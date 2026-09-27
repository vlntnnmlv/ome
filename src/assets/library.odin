package omeassets

import "core:log"
import "core:strings"

import "ome:gpu"
import "ome:handle_map"


Error :: enum {
	None = 0,
	File,
	Init,
	Pack,
	GPU,
	Duplicate_Name,
}

Library :: struct {
	device:        ^gpu.Device,
	fonts:         handle_map.Map(Font, FontHandle),
	atlases:       handle_map.Map(Atlas, AtlasHandle),
	texture_names: map[string]gpu.TextureHandle,
	atlas_names:   map[string]AtlasHandle,
	font_names:    map[string]FontHandle,
}

library_create :: proc(device: ^gpu.Device) -> ^Library {
	library: ^Library = new(Library)

	font_map, fm_err := handle_map.make(Font, FontHandle)
	ensure(fm_err == nil)

	atlas_map, am_err := handle_map.make(Atlas, AtlasHandle)
	ensure(am_err == nil)

	library.device = device
	library.fonts = font_map
	library.atlases = atlas_map

	library.texture_names = make(map[string]gpu.TextureHandle)
	library.atlas_names = make(map[string]AtlasHandle)
	library.font_names = make(map[string]FontHandle)

	return library
}

library_load_font :: proc(
	library: ^Library,
	path: string,
	name: string,
	sizes: []u32 = {},
) -> (
	FontHandle,
	Error,
) {
	font_handle, err := handle_map.add(&library.fonts, Font{})
	ensure(err == nil)

	font := handle_map.get(library.fonts, font_handle)
	ferr := font_load(font, path, sizes)
	if ferr != .None {
		font_destroy(font)
		handle_map.remove(&library.fonts, font_handle)
		return {}, ferr
	}

	if name not_in library.font_names {
		library.font_names[strings.clone(name)] = font_handle
	} else {
		log.warnf("assets: font with name '%s' already exists", name)
	}

	return font_handle, .None
}

library_get_font :: proc(library: ^Library, handle: FontHandle) -> ^Font {
	return handle_map.get(library.fonts, handle)
}

library_find_font :: proc(library: ^Library, name: string) -> (FontHandle, bool) {
	handle, found := library.font_names[name]
	return handle, found
}

library_load_atlas :: proc(
	library: ^Library,
	directory_path: string,
	name: string,
) -> (
	AtlasHandle,
	Error,
) {
	atlas_handle, err := handle_map.add(&library.atlases, Atlas{})
	ensure(err == nil)

	atlas := handle_map.get(library.atlases, atlas_handle)

	aerr := atlas_load(atlas, library.device.bind_table, directory_path, name)
	if aerr != .None {
		atlas_destroy(atlas)
		handle_map.remove(&library.atlases, atlas_handle)
		return {}, aerr
	}

	if name not_in library.atlas_names {
		library.atlas_names[strings.clone(name)] = atlas_handle
	} else {
		log.warnf("assets: atlas with name '%s' already exists", name)
	}

	return atlas_handle, .None
}

library_get_atlas :: proc(library: ^Library, handle: AtlasHandle) -> ^Atlas {
	return handle_map.get(library.atlases, handle)
}

library_find_atlas :: proc(library: ^Library, name: string) -> (AtlasHandle, bool) {
	handle, found := library.atlas_names[name]
	return handle, found
}

library_load_texture :: proc(
	library: ^Library,
	path: string,
	name: string,
) -> (
	gpu.TextureHandle,
	Error,
) {
	if name in library.texture_names {
		log.warnf("assets: texture with name '%s' already exists", name)
		return gpu.TextureHandle{}, .Duplicate_Name
	}
	texture_handle, err := gpu.texture_create(library.device.bind_table, path, name)
	if err != .None {
		return {}, .GPU
	}

	library.texture_names[strings.clone(name)] = texture_handle
	return texture_handle, .None
}

library_find_texture :: proc(library: ^Library, name: string) -> (gpu.TextureHandle, bool) {
	handle, found := library.texture_names[name]
	return handle, found
}

library_flush :: proc(library: ^Library) {
	iter := handle_map.make_iter(&library.fonts)
	for font in handle_map.iter(&iter) {
		font_flush(font, library.device.bind_table)
	}
}

library_destroy :: proc(library: ^Library) {
	for name, _ in library.texture_names {
		delete(name)
	}
	for name, _ in library.atlas_names {
		delete(name)
	}
	for name, _ in library.font_names {
		delete(name)
	}

	fiter := handle_map.make_iter(&library.fonts)
	for font in handle_map.iter(&fiter) {
		font_destroy(font)
	}

	aiter := handle_map.make_iter(&library.atlases)
	for atlas in handle_map.iter(&aiter) {
		atlas_destroy(atlas)
	}

	delete(library.texture_names)
	delete(library.atlas_names)
	delete(library.font_names)

	handle_map.delete(&library.fonts)
	handle_map.delete(&library.atlases)

	free(library)
}
