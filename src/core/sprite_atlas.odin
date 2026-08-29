package ome

import "core:fmt"
import "core:mem"
import "core:path/filepath"
import "core:strings"

import STBI "vendor:stb/image"
import STBR "vendor:stb/rect_pack"

SpriteAtlas :: struct {
	handle:  TextureHandle,
	sprites: map[string](SpriteData),
	size:    f32,
}

SpriteData :: struct {
	uvs: []Uv,
	x:   f32,
	y:   f32,
	w:   f32,
	h:   f32,
}

sprite_atlas_create_from_directory :: proc(
	renderer: ^Renderer,
	directory_path: string,
	atlas_name: string,
) -> SpriteAtlas {
	names: []string = get_texture_paths_in_derectory(directory_path)

	defer {
		for name in names do delete(name)
		delete(names)
	}

	return sprite_atlas_create(renderer, names[:], atlas_name)
}

sprite_atlas_create :: proc(renderer: ^Renderer, paths: []string, name: string) -> SpriteAtlas {
	w, h, channels: i32
	textures_data: [dynamic]TextureData
	rects: [dynamic]STBR.Rect
	sprites := make(map[string](SpriteData))

	for i in 0 ..< len(paths) {
		pixels := STBI.load(
			strings.clone_to_cstring(paths[i], allocator = context.temp_allocator),
			&w,
			&h,
			&channels,
			4,
		)
		rect: STBR.Rect = {
			id = i32(i),
			w  = STBR.Coord(w),
			h  = STBR.Coord(h),
		}
		append(&rects, rect)

		texture_data: TextureData = {
			pixels = pixels,
			w = w,
			h = h,
			channels = channels,
			in_atlas = true,
			atlas_rect = Rect{w = f32(w), h = f32(h)},
			name = strings.clone(filepath.stem(paths[i])),
		}
		append(&textures_data, texture_data)
	}

	defer delete(textures_data)
	defer delete(rects)

	atlas_size: i32 = 512
	ctxt: STBR.Context
	nodes: []STBR.Node = make([]STBR.Node, atlas_size)

	defer delete(nodes)

	STBR.init_target(&ctxt, atlas_size, atlas_size, raw_data(nodes), atlas_size)
	pack_result := STBR.pack_rects(&ctxt, raw_data(rects), i32(len(rects)))

	for i in 0 ..< len(rects) {
		textures_data[i].atlas_rect.x = f32(rects[i].x)
		textures_data[i].atlas_rect.y = f32(rects[i].y)
		textures_data[i].atlas_rect.w = f32(rects[i].w)
		textures_data[i].atlas_rect.h = f32(rects[i].h)
		textures_data[i].in_atlas = bool(rects[i].was_packed)

		sprites[textures_data[i].name] = SpriteData {
			uvs = rect_to_uvs_atlas(
				textures_data[i].atlas_rect,
				{f32(atlas_size), f32(atlas_size)},
				allocator = context.allocator,
			)[:],
			x   = textures_data[i].atlas_rect.x,
			y   = textures_data[i].atlas_rect.y,
			w   = textures_data[i].atlas_rect.w,
			h   = textures_data[i].atlas_rect.h,
		}
	}

	if pack_result == 0 {
		fmt.println("Failed to pack", pack_result)
	}

	atlas_data: TextureData = {
		pixels   = raw_data(make([]byte, atlas_size * atlas_size * 4)),
		w        = atlas_size,
		h        = atlas_size,
		channels = 4,
		name     = name,
	}
	defer free(atlas_data.pixels)

	for texture_data in textures_data {
		defer STBI.image_free(texture_data.pixels)
	}

	handle: TextureHandle = sprite_atlas_build(renderer, textures_data[:], atlas_data)
	for n, sprite in sprites {
		fmt.println("Sprite:", n, sprite.uvs, sep = ";")
	}
	return SpriteAtlas{handle = handle, sprites = sprites, size = f32(atlas_size)}
}

sprite_atlas_build :: proc(
	renderer: ^Renderer,
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
			dst_offset := ((int(rect.y) + row) * int(atlas_data.w) + int(rect.x)) * 4
			src_offset := row * row_bytes
			mem.copy(&atlas_data.pixels[dst_offset], &src[src_offset], row_bytes)
		}
	}

	handle := texture_create_from_data(renderer, atlas_data)

	// STBI.write_png(
	// 	"a.png",
	// 	atlas_data.w,
	// 	atlas_data.h,
	// 	atlas_data.channels,
	// 	atlas_data.pixels,
	// 	atlas_data.w * atlas_data.channels,
	// )
	return handle
}
