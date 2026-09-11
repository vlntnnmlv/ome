package omeresources

import "base:builtin"
import "base:runtime"
import "core:strings"

import "ome:core/gpu"
import "ome:core/handle_map"

Assets :: struct {
	device:        ^gpu.Device,
	fonts:         handle_map.HandleMap(Font, FontHandle),
	atlases:       handle_map.HandleMap(Atlas, AtlasHandle),
	texture_names: map[string]gpu.TextureHandle,
}

create :: proc(renderer: ^gpu.Device) -> ^Assets {
	assets: ^Assets = new(Assets)

	font_map, fm_err := handle_map.make(Font, FontHandle)
	assert(fm_err == runtime.Allocator_Error.None)

	atlas_map, am_err := handle_map.make(Atlas, AtlasHandle)
	assert(am_err == runtime.Allocator_Error.None)

	assets.device = renderer
	assets.fonts = font_map
	assets.atlases = atlas_map
	assets.texture_names = make_map(map[string]gpu.TextureHandle)

	return assets
}

load_font :: proc(assets: ^Assets, path: string, sizes: []u32 = {}) -> (FontHandle, FontError) {
	font_handle, err := handle_map.add(&assets.fonts, Font{})
	assert(err == runtime.Allocator_Error.None)

	font := handle_map.get(assets.fonts, font_handle)
	ferr := font_load(font, path, sizes)
	return font_handle, ferr
}

get_font :: proc(assets: ^Assets, handle: FontHandle) -> ^Font {
	return handle_map.get(assets.fonts, handle)
}

load_atlas :: proc(
	assets: ^Assets,
	directory_path: string,
	name: string,
) -> (
	AtlasHandle,
	AtlasError,
) {
	atlas_handle, err := handle_map.add(&assets.atlases, Atlas{})
	assert(err == runtime.Allocator_Error.None)

	atlas := handle_map.get(assets.atlases, atlas_handle)

	aerr := atlas_load(atlas, assets.device.bind_table, directory_path, name)
	return atlas_handle, aerr
}

get_atlas :: proc(resources: ^Assets, handle: AtlasHandle) -> ^Atlas {
	return handle_map.get(resources.atlases, handle)
}

load_texture :: proc(resources: ^Assets, path: string, name: string) -> gpu.TextureHandle {
	handle := gpu.texture_create(resources.device.bind_table, path, name)
	resources.texture_names[strings.clone(name)] = handle
	return handle
}

flush :: proc(resources: ^Assets) {
	iter := handle_map.make_iter(&resources.fonts)
	for font in handle_map.iter(&iter) {
		font_flush(font, resources.device.bind_table)
	}
}

delete :: proc(resources: ^Assets) {
	for name, _ in resources.texture_names {
		builtin.delete(name)
	}

	fiter := handle_map.make_iter(&resources.fonts)
	for font in handle_map.iter(&fiter) {
		font_delete(font)
	}

	aiter := handle_map.make_iter(&resources.atlases)
	for atlas in handle_map.iter(&aiter) {
		atlas_destroy(atlas)
	}

	delete_map(resources.texture_names)
	handle_map.delete(&resources.fonts)
	handle_map.delete(&resources.atlases)
}
