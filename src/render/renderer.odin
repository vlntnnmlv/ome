package omerender

import "core:log"

import STBTT "vendor:stb/truetype"

import "ome:assets"
import "ome:core"
import "ome:gpu"
import "ome:handle_map"
import "ome:platform"

@(private = "file")
CUBE_FACES := [6][4]int {
	{4, 5, 6, 7}, // +Z
	{0, 3, 2, 1}, // -Z
	{1, 2, 6, 5}, // +X
	{0, 4, 7, 3}, // -X
	{7, 6, 2, 3}, // +Y
	{0, 1, 5, 4}, // -Y
}

Renderer :: struct {
	device: ^gpu.Device,
	batch:  gpu.Batch,
	assets: ^assets.Instance,
}

create :: proc(
	device: ^gpu.Device,
	assets: ^assets.Instance,
	window_info: platform.WindowInfo,
) -> ^Renderer {
	renderer := new(Renderer)
	renderer.device = device
	renderer.assets = assets
	renderer.batch = gpu.batch_create(device, window_info)
	return renderer
}

begin :: proc(renderer: ^Renderer) {
	assets.flush(renderer.assets)
	gpu.device_begin(renderer.device)
	gpu.batch_clear(&renderer.batch)
}

flush :: proc(renderer: ^Renderer) {
	gpu.batch_flush(&renderer.batch, renderer.device)
}

present :: proc(renderer: ^Renderer) {
	gpu.device_present(renderer.device)
}

resize :: proc(renderer: ^Renderer, info: platform.WindowInfo) {
	gpu.device_resize(renderer.device, info)
	gpu.batch_resize(&renderer.batch, info)
}

set_camera :: proc(renderer: ^Renderer, index: u32) {
	gpu.batch_set_camera(&renderer.batch, index)
}

get_camera_2d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera2D {
	return gpu.batch_get_camera_2d(&renderer.batch, index)
}

set_camera_2d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera2D) {
	assert(index < gpu.MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

get_camera_3d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera3D {
	return gpu.batch_get_camera_3d(&renderer.batch, index)
}

set_camera_3d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera3D) {
	assert(index < gpu.MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

destroy :: proc(renderer: ^Renderer) {
	gpu.device_wait_idle(renderer.device)

	assets.destroy(renderer.assets)
	free(renderer.assets)

	gpu.batch_destroy(&renderer.batch)

	gpu.device_destroy(renderer.device)
	free(renderer.device)

	free(renderer)
}

line :: proc(
	renderer: ^Renderer,
	start: [2]f32,
	end: [2]f32,
	color: core.Color = core.BLACK,
	thickness: int = 1,
) {
	gpu.batch_add_points(&renderer.batch, {start, end}, color, false, thickness)
}

segments :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: core.Color = core.BLACK,
	thickness: int = 1,
	fill: bool = false,
) {
	gpu.batch_add_points(&renderer.batch, points, color, fill, thickness)
}

curve :: proc(
	renderer: ^Renderer,
	curve_points: [][2]f32,
	color: core.Color = core.BLACK,
	thickness: int = 1,
	fill: bool = false,
) {
	assert(len(curve_points) == 3, "Curve rendering supports only 3 points")

	points: [100][2]f32
	for i in 0 ..< 100 {
		phase: f32 = (f32(i) + 1.0) / 100.0
		a_to_b := core.interpolate(curve_points[0], curve_points[1], phase)
		b_to_c := core.interpolate(curve_points[1], curve_points[2], phase)
		points[i] = core.interpolate(a_to_b, b_to_c, phase)
	}
	segments(renderer, points[:], color, thickness, fill)
}


quad :: proc(
	renderer: ^Renderer,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	thickness: int = 1,
	fill: bool = false,
) {
	segments(
		renderer,
		{
			{rect.x, rect.y},
			{rect.x + rect.w, rect.y},
			{rect.x + rect.w, rect.y + rect.h},
			{rect.x, rect.y + rect.h},
			{rect.x, rect.y},
		},
		color,
		thickness,
		fill,
	)
}

rect :: proc(renderer: ^Renderer, rect: core.Rect, color: core.Color = core.BLACK) {
	gpu.batch_add_quad(&renderer.batch, rect, color)
}

text :: proc(
	renderer: ^Renderer,
	text: string,
	font_handle: assets.FontHandle,
	font_size: u32,
	rect: core.Rect,
	color: core.Color = core.BLACK,
) {
	font := assets.get_font(renderer.assets, font_handle)

	wanted_font_size := assets.text_fit(font, text, font_size, rect)
	assets.font_ensure_size(font, wanted_font_size)
	real_font_size := assets.font_nearest_size(font, wanted_font_size)

	x := rect.x
	y := rect.y

	cap := len(text) * gpu.VERTICES_PER_QUAD
	total_positions := make([dynamic]gpu.Position, 0, cap, context.temp_allocator)
	total_uvs := make([dynamic]gpu.Uv, 0, cap, context.temp_allocator)

	start := len(renderer.batch.vertices.cpu)
	it := assets.StringPrintableIterator{text, 0}
	for char in assets.iterate_printable(&it) {
		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&font.char_data[real_font_size][0],
			font.bitmap_size,
			font.bitmap_size,
			cast(i32)char - 32,
			&x,
			&y,
			&quad,
			true,
		)

		char_rect := core.Rect{quad.x0, quad.y0, quad.x1 - quad.x0, quad.y1 - quad.y0}
		vertices := gpu.rect_to_vertices_positions(char_rect)

		uvs := [gpu.VERTICES_PER_QUAD]gpu.Uv {
			{quad.s0, quad.t0},
			{quad.s0, quad.t1},
			{quad.s1, quad.t1},
			{quad.s0, quad.t0},
			{quad.s1, quad.t1},
			{quad.s1, quad.t0},
		}

		append(&total_positions, ..vertices[:])
		append(&total_uvs, ..uvs[:])
	}

	vertices := gpu.vertices_positions_and_uvs_to_vertices(
		total_positions[:],
		total_uvs[:],
		color,
		gpu.Mode.Text,
		gpu.TexID(font.texture.idx),
	)

	gpu.buffer_append(&renderer.batch.vertices, vertices)
	gpu.batch_append_render_call(&renderer.batch, .Triangle, start, len(vertices))
}

texture :: proc {
	texture_by_handle,
	texture_by_name,
	texture_by_atlas_name,
}

texture_by_handle :: proc(
	renderer: ^Renderer,
	handle: gpu.TextureHandle,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
) {
	positions: [dynamic]gpu.Position
	uvs: [dynamic]gpu.Uv

	if slice_offset != core.ZERO_RECT_OFFSET {
		tex := handle_map.get(renderer.device.bind_table.textures, handle)
		tw := cast(f32)tex.data->width()
		th := cast(f32)tex.data->height()

		positions = gpu.rect_to_vertices_positions_nine_slice(rect, slice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice(slice_offset, tw, th)
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = gpu.rect_to_uvs({0, 0, 1, 1})
	}

	gpu.batch_add_texture(&renderer.batch, handle, positions[:], uvs[:], color)
}

texture_by_name :: proc(
	renderer: ^Renderer,
	name: string,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
) {
	handle, found := renderer.assets.texture_names[name]
	assert(found)

	positions: [dynamic]gpu.Position
	uvs: [dynamic]gpu.Uv

	if slice_offset != core.ZERO_RECT_OFFSET {
		tex := handle_map.get(renderer.device.bind_table.textures, handle)
		tw := cast(f32)tex.data->width()
		th := cast(f32)tex.data->height()

		positions = gpu.rect_to_vertices_positions_nine_slice(rect, slice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice(slice_offset, tw, th)
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = gpu.rect_to_uvs({0, 0, 1, 1})
	}

	gpu.batch_add_texture(&renderer.batch, handle, positions[:], uvs[:], color)
}

texture_by_atlas_name :: proc(
	renderer: ^Renderer,
	atlas_handle: assets.AtlasHandle,
	sprite_name: string,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
) {

	atlas := assets.get_atlas(renderer.assets, atlas_handle)

	positions: [dynamic]gpu.Position
	uvs: []gpu.Uv

	sprite, found := atlas.sprites[sprite_name]
	if !found {
		log.warnf("Sprite '%s' is not in atlas '%s'", sprite_name, atlas.name)
		return
	}

	if slice_offset != core.ZERO_RECT_OFFSET {
		positions = gpu.rect_to_vertices_positions_nine_slice(rect, slice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice_atlas(
			slice_offset,
			sprite.atlas_rect,
			{atlas.size, atlas.size},
		)[:]
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = sprite.uvs
	}

	gpu.batch_add_texture(&renderer.batch, atlas.texture_handle, positions[:], uvs, color)
}

cube :: proc(renderer: ^Renderer, center: [3]f32, size: f32, color: core.Color = core.BLACK) {
	h := size * 0.5
	corners := [8][3]f32 {
		{-h, -h, -h},
		{h, -h, -h},
		{h, h, -h},
		{-h, h, -h},
		{-h, -h, h},
		{h, -h, h},
		{h, h, h},
		{-h, h, h},
	}

	positions := make([dynamic]gpu.Position, 0, 36, context.temp_allocator)
	for face in CUBE_FACES {
		quad: [4]gpu.Position
		for corner_index, i in face {
			p := corners[corner_index] + center
			quad[i] = gpu.Position{p.x, p.y, p.z, 1}
		}
		append(&positions, quad[0], quad[1], quad[2], quad[0], quad[2], quad[3])
	}

	gpu.batch_add_mesh(&renderer.batch, positions[:], color)
}
