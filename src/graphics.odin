package ome

import "core:slice"

import MTL "vendor:darwin/Metal"
import STBTT "vendor:stb/truetype"

graphics_add_points :: proc(
	app: ^App,
	points: [][2]f32,
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	start := len(app.vertices.cpu)
	vertices_count := len(points)

	vertices := points_to_vertices(app, points)
	colors := get_n_colors(color, vertices_count)
	uvs := make([]Uv, vertices_count, context.temp_allocator)
	modes := make([]Mode, vertices_count, context.temp_allocator)
	tex_ids := make([]TexID, vertices_count, context.temp_allocator)

	gpu_buffer_append(&app.vertices, vertices[:])
	gpu_buffer_append(&app.colors, colors[:])
	gpu_buffer_append(&app.uvs, uvs[:])
	gpu_buffer_append(&app.modes, modes[:])
	gpu_buffer_append(&app.tex_ids, tex_ids[:])

	type: MTL.PrimitiveType = .LineStrip
	if fill do type = .Triangle
	append(&app.render_calls, RenderCall{type = type, start = start, count = vertices_count})
}

graphics_add_quad :: proc(app: ^App, rect: Rect, color: Maybe(Color) = nil) {
	start := len(app.vertices.cpu)
	vertices := rect_to_vertices(app, rect)
	vertices_count := len(vertices)

	colors := get_n_colors(color, vertices_count)
	uvs := make([dynamic]Uv, vertices_count, context.temp_allocator)
	modes := make([dynamic]Mode, vertices_count, context.temp_allocator)
	tex_ids := make([dynamic]TexID, vertices_count, context.temp_allocator)

	gpu_buffer_append(&app.vertices, vertices[:])
	gpu_buffer_append(&app.colors, colors[:])
	gpu_buffer_append(&app.uvs, uvs[:])
	gpu_buffer_append(&app.modes, modes[:])
	gpu_buffer_append(&app.tex_ids, tex_ids[:])

	append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = vertices_count})
}

graphics_add_text :: proc(
	app: ^App,
	text: string,
	font_size: f32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	real_font_size := text_fit(app, text, font_size, rect)
	assets_validate_font_size(app, real_font_size)

	x := rect.x
	y := rect.y

	for char in text {
		if char < CharAtStart || char > CharAtStart + CharAmount do continue

		quad: STBTT.aligned_quad
		STBTT.GetPackedQuad(
			&app.font.char_data[real_font_size][0],
			app.font.bitmap_size,
			app.font.bitmap_size,
			cast(i32)char - 32,
			&x,
			&y,
			&quad,
			true,
		)

		start := len(app.vertices.cpu)
		vertices := [6]Vertex {
			point_to_vertex(app, quad.x0, quad.y0),
			point_to_vertex(app, quad.x0, quad.y1),
			point_to_vertex(app, quad.x1, quad.y1),
			point_to_vertex(app, quad.x0, quad.y0),
			point_to_vertex(app, quad.x1, quad.y1),
			point_to_vertex(app, quad.x1, quad.y0),
		}
		uvs := [6]Uv {
			{quad.s0, quad.t0},
			{quad.s0, quad.t1},
			{quad.s1, quad.t1},
			{quad.s0, quad.t0},
			{quad.s1, quad.t1},
			{quad.s1, quad.t0},
		}
		colors := get_n_colors(color, 6)
		modes: [6]Mode = 1
		tex_ids := [6]TexID{}

		gpu_buffer_append(&app.vertices, vertices[:])
		gpu_buffer_append(&app.colors, colors[:])
		gpu_buffer_append(&app.uvs, uvs[:])
		gpu_buffer_append(&app.modes, modes[:])
		gpu_buffer_append(&app.tex_ids, tex_ids[:])

		append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = 6})
	}
}

graphics_add_texture :: proc(
	app: ^App,
	texture_handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	start := len(app.vertices.cpu)
	positions: [dynamic]Vertex
	uvs: [dynamic]Uv

	if rslice_offset, ok := slice_offset.?; ok {
		tex := app.texture_manager.textures[texture_handle]
		tw := cast(f32)tex->width()
		th := cast(f32)tex->height()

		positions = rect_to_vertices_nine_slice(app, rect, rslice_offset)
		uvs = offset_to_uvs_nine_slice(rslice_offset, tw, th)
	} else {
		positions = rect_to_vertices(app, rect)
		uvs = rect_to_uvs({0, 0, 1, 1})
	}

	vertices_count := len(positions)

	colors := get_n_colors(color, vertices_count)

	modes := make([dynamic]Mode, vertices_count, context.temp_allocator)
	slice.fill(modes[:], 2)

	tex_ids := make([dynamic]TexID, vertices_count, context.temp_allocator)
	slice.fill(tex_ids[:], TexID(texture_handle))

	gpu_buffer_append(&app.vertices, positions[:])
	gpu_buffer_append(&app.colors, colors[:])
	gpu_buffer_append(&app.uvs, uvs[:])
	gpu_buffer_append(&app.modes, modes[:])
	gpu_buffer_append(&app.tex_ids, tex_ids[:])

	append(&app.render_calls, RenderCall{type = .Triangle, start = start, count = vertices_count})
}
