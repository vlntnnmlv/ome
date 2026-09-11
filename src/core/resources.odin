package omecore

import "base:runtime"
import "core:strings"
import "ome:core/handle_map"

Resources :: struct {
	gpu:           ^Renderer,
	fonts:         handle_map.HandleMap(Font, FontHandle),
	atlases:       handle_map.HandleMap(Atlas, AtlasHandle),
	texture_names: map[string]TextureHandle,
}

resources_create :: proc(gpu: ^Renderer) -> ^Resources {
	resources: ^Resources = new(Resources)

	font_map, fm_err := handle_map.make(Font, FontHandle)
	assert(fm_err == runtime.Allocator_Error.None)

	atlas_map, am_err := handle_map.make(Atlas, AtlasHandle)
	assert(am_err == runtime.Allocator_Error.None)

	resources.gpu = gpu
	resources.fonts = font_map
	resources.atlases = atlas_map
	resources.texture_names = make_map(map[string]TextureHandle)

	return resources
}

resources_load_font :: proc(
	resources: ^Resources,
	path: string,
	sizes: []u32 = {},
) -> (
	FontHandle,
	FontError,
) {
	font_handle, err := handle_map.add(&resources.fonts, Font{})
	assert(err == runtime.Allocator_Error.None)

	font := handle_map.get(resources.fonts, font_handle)
	ferr := font_load(font, path, sizes)
	return font_handle, ferr
}

resources_get_font :: proc(resources: ^Resources, handle: FontHandle) -> ^Font {
	return handle_map.get(resources.fonts, handle)
}

resources_load_atlas :: proc(
	resources: ^Resources,
	directory_path: string,
	name: string,
) -> (
	AtlasHandle,
	AtlasError,
) {
	atlas_handle, err := handle_map.add(&resources.atlases, Atlas{})
	assert(err == runtime.Allocator_Error.None)

	atlas := handle_map.get(resources.atlases, atlas_handle)

	aerr := sprite_atlas_load(atlas, resources.gpu.texture_manager, directory_path, name)
	return atlas_handle, aerr
}

resources_get_atlas :: proc(resources: ^Resources, handle: AtlasHandle) -> ^Atlas {
	return handle_map.get(resources.atlases, handle)
}

resources_load_texture :: proc(
	resources: ^Resources,
	path: string,
	name: string,
) -> TextureHandle {
	handle := texture_create(resources.gpu.texture_manager, path, name)
	resources.texture_names[strings.clone(name)] = handle
	return handle
}

resources_flush :: proc(resources: ^Resources) {
	iter := handle_map.make_iter(&resources.fonts)
	for font in handle_map.iter(&iter) {
		font_flush(font, resources.gpu.texture_manager)
	}
}

resources_delete :: proc(resources: ^Resources) {
	for name, _ in resources.texture_names {
		delete(name)
	}

	fiter := handle_map.make_iter(&resources.fonts)
	for font in handle_map.iter(&fiter) {
		font_delete(font)
	}

	aiter := handle_map.make_iter(&resources.atlases)
	for atlas in handle_map.iter(&aiter) {
		sprite_atlas_destroy(atlas)
	}

	delete_map(resources.texture_names)
	handle_map.delete(&resources.fonts)
	handle_map.delete(&resources.atlases)
}
