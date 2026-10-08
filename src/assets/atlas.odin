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

@(private)
MIN_ATLAS_SIZE :: 512

@(private)
MAX_ATLAS_SIZE :: 4096

@(private)
ATLAS_SPRITE_SPACING :: 2

AtlasHandle :: distinct handle_map.Handle

Atlas :: struct {
	handle:         AtlasHandle,
	texture_handle: gpu.TextureHandle,
	name:           string,
	sprites:        map[string](SpriteData),
	size:           [2]f32,
}

SpriteData :: struct {
	atlas_rect: core.Rect,
	uv_rect:    core.Rect,
}

@(private)
AtlasImage :: struct {
	name:   string,
	pixels: [^]byte,
	width:  i32,
	height: i32,
	rect:   core.Rect,
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
	images: [dynamic]AtlasImage
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
			w  = STBRP.Coord(width) + 2 * ATLAS_SPRITE_SPACING,
			h  = STBRP.Coord(height) + 2 * ATLAS_SPRITE_SPACING,
		}
		append(&rects, rect)

		image: AtlasImage = {
			name   = strings.clone(filepath.stem(paths[i])),
			pixels = pixels,
			width  = width,
			height = height,
		}

		append(&images, image)
	}

	defer {
		delete(rects)
		for image in images {
			STBI.image_free(image.pixels)
		}
		delete(images)
	}

	nodes := make([]STBRP.Node, MAX_ATLAS_SIZE)
	defer delete(nodes)

	atlas_size: i32 = MIN_ATLAS_SIZE
	for {
		ctx: STBRP.Context
		STBRP.init_target(&ctx, atlas_size, atlas_size, raw_data(nodes), atlas_size)
		if STBRP.pack_rects(&ctx, raw_data(rects), i32(len(rects))) != 0 {
			break
		}

		if atlas_size >= MAX_ATLAS_SIZE {
			for image in images {
				delete(image.name)
			}
			delete(sprites)
			log.errorf(
				"assets/atlas: '%s' doesn't fit in %dx%d",
				name,
				MAX_ATLAS_SIZE,
				MAX_ATLAS_SIZE,
			)
			return .Pack
		}
		atlas_size *= 2
	}
	log.infof("assets/atlas: atlas '%s' packed successfully", name)

	size := f32(atlas_size)
	for &image, i in images {
		image.rect = core.Rect {
			f32(rects[i].x + ATLAS_SPRITE_SPACING),
			f32(rects[i].y + ATLAS_SPRITE_SPACING),
			f32(rects[i].w - 2 * ATLAS_SPRITE_SPACING),
			f32(rects[i].h - 2 * ATLAS_SPRITE_SPACING),
		}

		sprites[image.name] = SpriteData {
			atlas_rect = image.rect,
			uv_rect    = core.Rect {
				image.rect.x / size,
				image.rect.y / size,
				image.rect.w / size,
				image.rect.h / size,
			},
		}
	}

	pixels := make([]byte, atlas_size * atlas_size * 4)
	defer delete(pixels)

	atlas_data: gpu.TextureData = {
		pixels = raw_data(pixels),
		width  = atlas_size,
		height = atlas_size,
		name   = name,
	}

	texture_handle, gpu_err := atlas_build_texture(bind_table, images[:], atlas_data)
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
	images: []AtlasImage,
	atlas_data: gpu.TextureData,
) -> (
	gpu.TextureHandle,
	gpu.Error,
) {
	for image in images {
		src := image.pixels
		rect := image.rect
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
