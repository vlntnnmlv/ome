package omeassets

import "core:log"
import "core:mem"
import "core:path/filepath"
import "core:strings"

import STBI "vendor:stb/image"
import STBRP "vendor:stb/rect_pack"

import "ome:core"
import "ome:gpu"
import "ome:handle_map"

AtlasHandle :: distinct handle_map.Handle

Atlas :: struct {
	handle:         AtlasHandle,
	texture_handle: gpu.TextureHandle,
	name:           string,
	sprites:        map[string](SpriteData),
	size:           f32,
}

SpriteData :: struct {
	uvs:        [gpu.VERTICES_PER_QUAD]gpu.UV,
	atlas_rect: core.Rect,
	uv_rect:    core.Rect,
}

@(private)
atlas_load :: proc {
	atlas_load_from_directory,
	atlas_load_from_files,
}

@(private)
atlas_load_from_directory :: proc(
	atlas: ^Atlas,
	bind_table: ^gpu.BindTable,
	directory_path: string,
	atlas_name: string,
) -> Error {
	names, ok := core.directory_list_files(directory_path)
	if !ok {
		return .File
	}

	defer {
		for name in names {
			delete(name)
		}

		delete(names)
	}

	return atlas_load_from_files(atlas, bind_table, names[:], atlas_name)
}

@(private)
atlas_load_from_files :: proc(
	atlas: ^Atlas,
	bind_table: ^gpu.BindTable,
	paths: []string,
	name: string,
) -> Error {
	width, height, channels: i32
	textures_data: [dynamic]gpu.TextureData
	rects: [dynamic]STBRP.Rect
	sprites := make(map[string](SpriteData))

	for i in 0 ..< len(paths) {
		cpath := strings.clone_to_cstring(paths[i])
		defer delete(cpath)
		pixels := STBI.load(cpath, &width, &height, &channels, 4)
		if pixels == nil {
			log.errorf(
				"assets/atlas: failed to load texture at path '%s' with error %s",
				cpath,
				STBI.failure_reason(),
			)
			continue
		}
		rect: STBRP.Rect = {
			id = i32(i),
			w  = STBRP.Coord(width),
			h  = STBRP.Coord(height),
		}
		append(&rects, rect)

		texture_data: gpu.TextureData = {
			pixels = pixels,
			width = width,
			height = height,
			channels = 4,
			in_atlas = true,
			atlas_rect = core.Rect{w = f32(width), h = f32(height)},
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
	ctx: STBRP.Context
	nodes: []STBRP.Node = make([]STBRP.Node, atlas_size)

	defer delete(nodes)

	STBRP.init_target(&ctx, atlas_size, atlas_size, raw_data(nodes), atlas_size)
	pack_result := STBRP.pack_rects(&ctx, raw_data(rects), i32(len(rects)))

	if pack_result == 0 {
		for texture_data in textures_data {
			delete(texture_data.name)
		}
		delete(sprites)
		log.infof("assets/atlas: failed to pack atlas '%s'", name)
		return .Pack
	} else {
		log.infof("assets/atlas: atlas '%s' packed successfully", name)
	}

	// uvs: [gpu.VERTICES_PER_QUAD]gpu.UV
	for i in 0 ..< len(rects) {
		textures_data[i].atlas_rect.x = f32(rects[i].x)
		textures_data[i].atlas_rect.y = f32(rects[i].y)
		textures_data[i].atlas_rect.w = f32(rects[i].w)
		textures_data[i].atlas_rect.h = f32(rects[i].h)
		textures_data[i].in_atlas = bool(rects[i].was_packed)

		sprites[textures_data[i].name] = SpriteData {
			uvs        = gpu.rect_to_uvs_atlas(
				textures_data[i].atlas_rect,
				{f32(atlas_size), f32(atlas_size)},
			),
			atlas_rect = textures_data[i].atlas_rect,
			uv_rect    = core.Rect {
				textures_data[i].atlas_rect.x / f32(atlas_size),
				textures_data[i].atlas_rect.y / f32(atlas_size),
				textures_data[i].atlas_rect.w / f32(atlas_size),
				textures_data[i].atlas_rect.h / f32(atlas_size),
			},
		}
	}

	pixels := make([]byte, atlas_size * atlas_size * 4)
	defer delete(pixels)

	atlas_data: gpu.TextureData = {
		pixels   = raw_data(pixels),
		width    = atlas_size,
		height   = atlas_size,
		channels = 4,
		name     = name,
	}

	texture_handle, gpu_err := atlas_build_texture(bind_table, textures_data[:], atlas_data)
	atlas.texture_handle = texture_handle
	atlas.sprites = sprites
	atlas.size = f32(atlas_size)
	atlas.name = strings.clone(atlas_data.name)

	if gpu_err != .None {
		return .GPU
	}
	return .None
}

@(private)
atlas_build_texture :: proc(
	bind_table: ^gpu.BindTable,
	textures_data: []gpu.TextureData,
	atlas_data: gpu.TextureData,
) -> (
	gpu.TextureHandle,
	gpu.Error,
) {
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

	return gpu.texture_create_from_data(bind_table, atlas_data)
}

@(private)
atlas_destroy :: proc(atlas: ^Atlas) {
	for name in atlas.sprites {
		delete(name)
	}

	delete(atlas.sprites)
	delete(atlas.name)
}
