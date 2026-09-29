package omerender

import "core:log"

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
	batch_add_points(&renderer.batch, {start, end}, color, thickness)
}

segments :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: core.Color = core.BLACK,
	thickness: int = 1,
) {
	batch_add_points(&renderer.batch, points, color, thickness)
}

curve :: proc(
	renderer: ^Renderer,
	curve_points: [][2]f32,
	color: core.Color = core.BLACK,
	thickness: int = 1,
) {
	assert(len(curve_points) == 3, "Curve rendering supports only 3 points")

	points: [100][2]f32
	for i in 0 ..< 100 {
		phase: f32 = (f32(i) + 1.0) / 100.0
		a_to_b := core.interpolate_f32(curve_points[0], curve_points[1], phase)
		b_to_c := core.interpolate_f32(curve_points[1], curve_points[2], phase)
		points[i] = core.interpolate_f32(a_to_b, b_to_c, phase)
	}
	segments(renderer, points[:], color, thickness)
}


quad :: proc(
	renderer: ^Renderer,
	rect: core.Rect,
	color: core.Color = core.BLACK,
	thickness: int = 1,
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
	)
}

rect :: proc(renderer: ^Renderer, rect: core.Rect, color: core.Color = core.BLACK) {
	batch_add_quad(&renderer.batch, rect, color)
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

	it := assets.font_make_glyphs_iterator(font, text, real_font_size, {rect.x, rect.y})
	for glyph in assets.font_iter_glyphs(&it) {
		positions := rect_to_vertices_positions(glyph.rect)
		uvs := rect_to_uvs(glyph.uv_rect)
		batch_add_texture(&renderer.batch, font.texture_handle, positions[:], uvs[:], color, .Text)
	}
}

sprite :: proc(
	renderer: ^Renderer,
	atlas_handle: assets.AtlasHandle,
	sprite_name: string,
	rect: core.Rect,
	color: core.Color = core.WHITE,
	slice_offset: core.RectOffset = core.ZERO_RECT_OFFSET,
	flip: core.Flip = {},
) {
	atlas := assets.library_get_atlas(renderer.library, atlas_handle)
	sprite, found := atlas.sprites[sprite_name]
	if !found {
		log.warnf("render: sprite '%s' is not in atlas '%s'", sprite_name, atlas.name)
		return
	}
	textured_quad(
		renderer,
		atlas.texture_handle,
		sprite.uv_rect,
		atlas.size,
		rect,
		color,
		slice_offset,
		flip,
	)
}


image :: proc(
	renderer: ^Renderer,
	image_handle: assets.ImageHandle,
	rect: core.Rect,
	color := core.WHITE,
	slice_offset := core.ZERO_RECT_OFFSET,
	flip: core.Flip = {},
) {
	image := assets.library_get_image(renderer.library, image_handle)
	if image == nil {
		return
	}

	textured_quad(
		renderer,
		image.texture_handle,
		core.UNIT_RECT,
		image.size,
		rect,
		color,
		slice_offset,
		flip,
	)
}

@(private)
textured_quad :: proc(
	renderer: ^Renderer,
	texture_handle: gpu.TextureHandle,
	uv_rect: core.Rect,
	texture_size: [2]f32,
	rect: core.Rect,
	color: core.Color,
	slice_offset: core.RectOffset,
	flip: core.Flip,
) {
	positions: []gpu.Position
	uvs: []gpu.UV

	positions_buffer: [VERTICES_PER_NINE_SLICED_QUAD]gpu.Position
	uvs_buffer: [VERTICES_PER_NINE_SLICED_QUAD]gpu.UV

	offset := core.rect_offset_flip(slice_offset, flip)
	if offset != core.ZERO_RECT_OFFSET {
		positions_buffer = rect_to_vertices_positions_nine_slice(rect, offset)
		uvs_buffer = rect_offset_to_uvs_nine_slice_atlas(offset, uv_rect, texture_size)

		positions = positions_buffer[:]
		uvs = uvs_buffer[:]
	} else {
		quad_positions := rect_to_vertices_positions(rect)
		copy(positions_buffer[:], quad_positions[:])

		quad_uvs := rect_to_uvs(uv_rect)
		copy(uvs_buffer[:], quad_uvs[:])

		positions = positions_buffer[:VERTICES_PER_QUAD]
		uvs = uvs_buffer[:VERTICES_PER_QUAD]
	}

	uvs_mirror(uvs, uv_rect, flip)
	batch_add_texture(&renderer.batch, texture_handle, positions, uvs, color)
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

	batch_add_mesh(&renderer.batch, positions[:], color)
}
