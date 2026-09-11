package omerender

import "core:log"

import STBTT "vendor:stb/truetype"

import "ome:core"
import "ome:core/gpu"
import "ome:core/handle_map"
import "ome:core/resources"

@(private = "file")
CUBE_FACES := [6][4]int {
	{4, 5, 6, 7}, // +Z
	{0, 3, 2, 1}, // -Z
	{1, 2, 6, 5}, // +X
	{0, 4, 7, 3}, // -X
	{7, 6, 2, 3}, // +Y
	{0, 1, 5, 4}, // -Y
}

@(private = "file")
resolve_color :: proc(color: Maybe(core.Color)) -> core.Color {
	if real_color, ok := color.?; ok {
		return real_color
	}
	return core.BLACK
}

line :: proc(
	renderer: ^gpu.Renderer,
	start: [2]f32,
	end: [2]f32,
	color: Maybe(core.Color) = nil,
	thickness: int = 1,
) {
	gpu.graphics_add_points(renderer, {start, end}, resolve_color(color), false, thickness)
}

segments :: proc(
	renderer: ^gpu.Renderer,
	points: [][2]f32,
	color: Maybe(core.Color) = nil,
	thickness: int = 1,
	fill: bool = false,
) {
	gpu.graphics_add_points(renderer, points, resolve_color(color), fill, thickness)
}

curve :: proc(
	renderer: ^gpu.Renderer,
	curve_points: [][2]f32,
	color: Maybe(core.Color) = nil,
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
	segments(renderer, points[:], resolve_color(color), thickness, fill)
}


quad :: proc(
	renderer: ^gpu.Renderer,
	rect: core.Rect,
	color: Maybe(core.Color) = nil,
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

rect :: proc(renderer: ^gpu.Renderer, rect: core.Rect, color: Maybe(core.Color) = nil) {
	gpu.graphics_add_quad(renderer, rect, resolve_color(color))
}

text :: proc(
	rsrcs: ^resources.Resources,
	text: string,
	font_handle: resources.FontHandle,
	font_size: u32,
	rect: core.Rect,
	color: Maybe(core.Color) = nil,
) {
	font := resources.resources_get_font(rsrcs, font_handle)

	wanted_font_size := resources.text_fit(font, text, font_size, rect)
	resources.font_ensure_size(font, wanted_font_size)
	real_font_size := resources.font_nearest_size(font, wanted_font_size)

	x := rect.x
	y := rect.y

	cap := len(text) * gpu.VERTICES_PER_QUAD
	total_positions := make([dynamic]gpu.Position, 0, cap, context.temp_allocator)
	total_uvs := make([dynamic]gpu.Uv, 0, cap, context.temp_allocator)

	start := len(rsrcs.renderer.vertices.cpu)
	it := resources.StringPrintableIterator{text, 0}
	for char in resources.iterate_printable(&it) {
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
		resolve_color(color),
		gpu.Mode.Text,
		gpu.TexID(font.texture.idx),
	)

	gpu.gpu_buffer_append(&rsrcs.renderer.vertices, vertices)

	gpu.graphics_append_render_call(rsrcs.renderer, .Triangle, start, len(vertices))
}

texture :: proc {
	texture_by_handle,
	texture_by_name,
	texture_by_atlas_name,
}

texture_by_handle :: proc(
	renderer: ^gpu.Renderer,
	handle: gpu.TextureHandle,
	rect: core.Rect,
	color: Maybe(core.Color) = nil,
	slice_offset: Maybe(core.RectOffset) = nil,
) {
	positions: [dynamic]gpu.Position
	uvs: [dynamic]gpu.Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := handle_map.get(renderer.bind_table.textures, handle)
		tw := cast(f32)tex.data->width()
		th := cast(f32)tex.data->height()

		positions = gpu.rect_to_vertices_positions_nine_slice(rect, rslice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = gpu.rect_to_uvs({0, 0, 1, 1})
	}

	gpu.graphics_add_texture(renderer, handle, positions[:], uvs[:], resolve_color(color))
}

texture_by_name :: proc(
	rsrcrs: ^resources.Resources,
	name: string,
	rect: core.Rect,
	color: Maybe(core.Color) = nil,
	slice_offset: Maybe(core.RectOffset) = nil,
) {
	handle, found := rsrcrs.texture_names[name]
	assert(found)

	positions: [dynamic]gpu.Position
	uvs: [dynamic]gpu.Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := handle_map.get(rsrcrs.renderer.bind_table.textures, handle)
		tw := cast(f32)tex.data->width()
		th := cast(f32)tex.data->height()

		positions = gpu.rect_to_vertices_positions_nine_slice(rect, rslice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = gpu.rect_to_uvs({0, 0, 1, 1})
	}

	gpu.graphics_add_texture(rsrcrs.renderer, handle, positions[:], uvs[:], resolve_color(color))
}

texture_by_atlas_name :: proc(
	rsrcs: ^resources.Resources,
	atlas_handle: resources.AtlasHandle,
	sprite_name: string,
	rect: core.Rect,
	color: Maybe(core.Color) = nil,
	slice_offset: Maybe(core.RectOffset) = nil,
) {

	atlas := resources.resources_get_atlas(rsrcs, atlas_handle)

	positions: [dynamic]gpu.Position
	uvs: []gpu.Uv

	sprite, found := atlas.sprites[sprite_name]
	if !found {
		log.warnf("Sprite '%s' is not in atlas '%s'", sprite_name, atlas.name)
		return
	}

	if rslice_offset, ok := slice_offset.?; ok {
		positions = gpu.rect_to_vertices_positions_nine_slice(rect, rslice_offset)
		uvs = gpu.rect_offset_to_uvs_nine_slice_atlas(
			rslice_offset,
			sprite.atlas_rect,
			{atlas.size, atlas.size},
		)[:]
	} else {
		positions = gpu.rect_to_vertices_positions(rect)
		uvs = sprite.uvs
	}

	gpu.graphics_add_texture(
		rsrcs.renderer,
		atlas.texture_handle,
		positions[:],
		uvs,
		resolve_color(color),
	)
}

cube :: proc(renderer: ^gpu.Renderer, center: [3]f32, size: f32, color: Maybe(core.Color) = nil) {
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

	gpu.graphics_add_mesh(renderer, positions[:], resolve_color(color))
}
