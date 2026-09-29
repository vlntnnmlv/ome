package omerender

import "core:log"
import "core:slice"

import "ome:assets"
import "ome:core"
import "ome:gpu"

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
		a_to_b := core.interpolate_f32(curve_points[0], curve_points[1], phase)
		b_to_c := core.interpolate_f32(curve_points[1], curve_points[2], phase)
		points[i] = core.interpolate_f32(a_to_b, b_to_c, phase)
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
	font := assets.library_get_font(renderer.library, font_handle)

	wanted_font_size := assets.font_text_fit(font, text, font_size, rect)
	assets.font_ensure_size(font, wanted_font_size)
	real_font_size := assets.font_nearest_size(font, wanted_font_size)

	start := len(renderer.batch.vertices.cpu)
	total_positions, total_uvs := assets.font_text_layout(
		font,
		text,
		real_font_size,
		{rect.x, rect.y},
	)

	vertices := gpu.vertices_positions_and_uvs_to_vertices(
		total_positions[:],
		total_uvs[:],
		color,
		gpu.Mode.Text,
		gpu.TextureID(font.texture_handle.idx),
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
	texture_handle: gpu.TextureHandle,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
	flip: core.Flip = {},
) {
	positions: [dynamic]gpu.Position
	uvs: [dynamic]gpu.UV

	if slice_offset != core.ZERO_RECT_OFFSET {
		tex_size, ok := gpu.texture_size(renderer.device.bind_table, texture_handle)
		if !ok {
			return
		}

		positions = gpu.rect_to_vertices_positions_nine_slice(rect, slice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice(slice_offset, tex_size.x, tex_size.y)
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = gpu.rect_to_uvs({0, 0, 1, 1})
	}

	gpu.uvs_mirror(uvs[:], core.UNIT_RECT, flip)

	gpu.batch_add_texture(&renderer.batch, texture_handle, positions[:], uvs[:], color)
}

texture_by_name :: proc(
	renderer: ^Renderer,
	name: string,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
	flip: core.Flip = {},
) {
	texture_handle, found := assets.library_find_texture(renderer.library, name)
	if !found {
		log.warnf("render: texture '%s' doesn't exist", name)
		return
	}

	texture_by_handle(renderer, texture_handle, rect, color, slice_offset, flip)
}

texture_by_atlas_name :: proc(
	renderer: ^Renderer,
	atlas_handle: assets.AtlasHandle,
	sprite_name: string,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
	flip: core.Flip = {},
) {
	atlas := assets.library_get_atlas(renderer.library, atlas_handle)

	positions: [dynamic]gpu.Position
	uvs: []gpu.UV

	sprite, found := atlas.sprites[sprite_name]
	if !found {
		log.warnf("render: sprite '%s' is not in atlas '%s'", sprite_name, atlas.name)
		return
	}

	if slice_offset != core.ZERO_RECT_OFFSET {
		positions = gpu.rect_to_vertices_positions_nine_slice(rect, slice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice_atlas(
			slice_offset,
			sprite.uv_rect,
			{atlas.size, atlas.size},
		)[:]
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = sprite.uvs
	}

	final_uvs := slice.clone(sprite.uvs, context.temp_allocator)
	gpu.uvs_mirror(final_uvs[:], sprite.uv_rect, flip)
	gpu.batch_add_texture(&renderer.batch, atlas.texture_handle, positions[:], final_uvs, color)
}

@(private = "file")
CUBE_FACES := [6][4]int {
	{4, 5, 6, 7}, // +Z
	{0, 3, 2, 1}, // -Z
	{1, 2, 6, 5}, // +X
	{0, 4, 7, 3}, // -X
	{7, 6, 2, 3}, // +Y
	{0, 1, 5, 4}, // -Y
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
