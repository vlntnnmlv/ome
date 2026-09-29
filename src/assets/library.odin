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
	// Duplicate_Name, TODO: Use for atlases, fonts and images
}

Library :: struct {
	device:      ^gpu.Device,
	fonts:       handle_map.Map(Font, FontHandle),
	atlases:     handle_map.Map(Atlas, AtlasHandle),
	images:      handle_map.Map(Image, ImageHandle),
	image_names: map[string]ImageHandle,
	atlas_names: map[string]AtlasHandle,
	font_names:  map[string]FontHandle,
}

library_create :: proc(device: ^gpu.Device) -> ^Library {
	library: ^Library = new(Library)

	font_map, fm_err := handle_map.make(Font, FontHandle)
	ensure(fm_err == nil)

	atlas_map, am_err := handle_map.make(Atlas, AtlasHandle)
	ensure(am_err == nil)

	image_map, im_err := handle_map.make(Image, ImageHandle)
	ensure(im_err == nil)

	library.device = device

	library.fonts = font_map
	library.atlases = atlas_map
	library.images = image_map

	library.image_names = make(map[string]ImageHandle)
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

library_load_image :: proc(library: ^Library, path: string, name: string) -> (ImageHandle, Error) {
	image_handle, err := handle_map.add(&library.images, Image{})
	ensure(err == nil)

	image := handle_map.get(library.images, image_handle)

	ierr := image_load(image, library.device.bind_table, path, name)
	if ierr != .None {
		image_destroy(image, library.device.bind_table)
		handle_map.remove(&library.images, image_handle)
		return {}, ierr
	}

	if name not_in library.image_names {
		library.image_names[strings.clone(name)] = image_handle
	} else {
		log.warnf("assets: image with name '%s' already exists", name)
	}

	return image_handle, .None
}

library_get_image :: proc(library: ^Library, handle: ImageHandle) -> ^Image {
	return handle_map.get(library.images, handle)
}

library_find_image :: proc(library: ^Library, name: string) -> (ImageHandle, bool) {
	handle, found := library.image_names[name]
	return handle, found
}

library_unload_image :: proc(library: ^Library, handle: ImageHandle) {
	image := handle_map.get(library.images, handle)
	if image == nil {
		return
	}

	for key, h in library.image_names {
		if h == handle {
			delete_key(&library.image_names, key)
			delete(key)
			break
		}
	}

	image_destroy(image, library.device.bind_table)
	handle_map.remove(&library.images, handle)
}

library_flush :: proc(library: ^Library) {
	iter := handle_map.make_iter(&library.fonts)
	for font in handle_map.iter(&iter) {
		font_flush(font, library.device.bind_table)
	}
}

library_destroy :: proc(library: ^Library) {
	for name, _ in library.image_names {
		delete(name)
	}
	for name, _ in library.atlas_names {
		delete(name)
	}
	for name, _ in library.font_names {
		delete(name)
	}

	iiter := handle_map.make_iter(&library.images)
	for image in handle_map.iter(&iiter) {
		image_destroy(image, library.device.bind_table)
	}

	fiter := handle_map.make_iter(&library.fonts)
	for font in handle_map.iter(&fiter) {
		font_destroy(font)
	}

	aiter := handle_map.make_iter(&library.atlases)
	for atlas in handle_map.iter(&aiter) {
		atlas_destroy(atlas)
	}

	delete(library.image_names)
	delete(library.atlas_names)
	delete(library.font_names)

	handle_map.delete(&library.images)
	handle_map.delete(&library.fonts)
	handle_map.delete(&library.atlases)

	free(library)
}
