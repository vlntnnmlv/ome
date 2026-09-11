package omecore

import "core:log"
import "core:mem"
import "core:path/filepath"
import "core:strings"
import "ome:core/handle_map"

import STBI "vendor:stb/image"
import STBR "vendor:stb/rect_pack"

AtlasError :: enum {
	None = 0,
	PackError,
}

AtlasHandle :: distinct handle_map.Handle

Atlas :: struct {
	handle:         AtlasHandle,
	texture_handle: TextureHandle,
	sprites:        map[string](SpriteData),
	size:           f32,
}

SpriteData :: struct {
	uvs:        []Uv,
	atlas_rect: Rect,
}

sprite_atlas_load :: proc {
	sprite_atlas_load_from_directory,
	sprite_atlas_load_from_files,
}

sprite_atlas_load_from_directory :: proc(
	atlas: ^Atlas,
	texture_manager: ^TextureManager,
	directory_path: string,
	atlas_name: string,
) -> AtlasError {
	names: []string = get_file_paths_in_directory(directory_path)

	defer {
		for name in names do delete(name)
		delete(names)
	}

	return sprite_atlas_load_from_files(atlas, texture_manager, names[:], atlas_name)
}

sprite_atlas_load_from_files :: proc(
	atlas: ^Atlas,
	texture_manager: ^TextureManager,
	paths: []string,
	name: string,
) -> AtlasError {
	width, height, channels: i32
	textures_data: [dynamic]TextureData
	rects: [dynamic]STBR.Rect
	sprites := make(map[string](SpriteData))

	for i in 0 ..< len(paths) {
		cpath := strings.clone_to_cstring(paths[i])
		defer delete(cpath)
		pixels := STBI.load(cpath, &width, &height, &channels, 4)
		rect: STBR.Rect = {
			id = i32(i),
			w  = STBR.Coord(width),
			h  = STBR.Coord(height),
		}
		append(&rects, rect)

		texture_data: TextureData = {
			pixels = pixels,
			width = width,
			height = height,
			channels = 4,
			in_atlas = true,
			atlas_rect = Rect{w = f32(width), h = f32(height)},
			name = strings.clone(filepath.stem(paths[i])),
		}
		append(&textures_data, texture_data)
	}

	defer {
		delete(rects)
		for texture_data in textures_data {
			STBI.image_free(texture_data.pixels)
		}
		delete(textures_data)
	}

	atlas_size: i32 = 512
	ctxt: STBR.Context
	nodes: []STBR.Node = make([]STBR.Node, atlas_size)

	defer delete(nodes)

	STBR.init_target(&ctxt, atlas_size, atlas_size, raw_data(nodes), atlas_size)
	pack_result := STBR.pack_rects(&ctxt, raw_data(rects), i32(len(rects)))

	if pack_result == 0 {
		delete_map(sprites)
		return .PackError
	} else {
		log.infof("Atlas '%s' packed succesfully", name)
	}

	for i in 0 ..< len(rects) {
		textures_data[i].atlas_rect.x = f32(rects[i].x)
		textures_data[i].atlas_rect.y = f32(rects[i].y)
		textures_data[i].atlas_rect.w = f32(rects[i].w)
		textures_data[i].atlas_rect.h = f32(rects[i].h)
		textures_data[i].in_atlas = bool(rects[i].was_packed)

		sprites[textures_data[i].name] = SpriteData {
			uvs        = rect_to_uvs_atlas(
				textures_data[i].atlas_rect,
				{f32(atlas_size), f32(atlas_size)},
				allocator = context.allocator,
			)[:],
			atlas_rect = textures_data[i].atlas_rect,
		}
	}

	pixels := make([]byte, atlas_size * atlas_size * 4)
	defer delete(pixels)

	atlas_data: TextureData = {
		pixels   = raw_data(pixels),
		width    = atlas_size,
		height   = atlas_size,
		channels = 4,
		name     = name,
	}

	handle: TextureHandle = sprite_atlas_build_texture(
		texture_manager,
		textures_data[:],
		atlas_data,
	)
	atlas.texture_handle = handle
	atlas.sprites = sprites
	atlas.size = f32(atlas_size)

	return .None
}

sprite_atlas_build_texture :: proc(
	texture_manager: ^TextureManager,
	textures_data: []TextureData,
	atlas_data: TextureData,
) -> TextureHandle {
	for texture_data in textures_data {
		if !texture_data.in_atlas {
			continue
		}

		src := texture_data.pixels
		rect := texture_data.atlas_rect
		row_bytes := int(rect.w) * 4

		for row in 0 ..< int(rect.h) {
			dst_offset := ((int(rect.y) + row) * int(atlas_data.width) + int(rect.x)) * 4
			src_offset := row * row_bytes
			mem.copy(&atlas_data.pixels[dst_offset], &src[src_offset], row_bytes)
		}
	}

	handle := texture_create_from_data(texture_manager, atlas_data)

	return handle
}

sprite_atlas_destroy :: proc(sprite_atlas: ^Atlas) {
	for name, sprite in sprite_atlas.sprites {
		delete(name)
		delete(sprite.uvs)
	}

	delete_map(sprite_atlas.sprites)
}
