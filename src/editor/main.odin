package omeeditor

import "core:fmt"
import "core:log"
import "core:math"
// import "core:math"
import "core:mem"

import OMECORE "../core"

main :: proc() {
	// system
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	defer {
		if len(tracking_allocator.allocation_map) > 0 {
			fmt.eprintf(
				"=== %v allocations not freed: ===\n",
				len(tracking_allocator.allocation_map),
			)
			for _, entry in tracking_allocator.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}

		mem.tracking_allocator_destroy(&tracking_allocator)
	}

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)


	// window
	width: f32 = 1080
	height: f32 = 720

	app, ok := OMECORE.app_create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer OMECORE.app_close(app)

	// load assets
	OMECORE.assets_load_font(app.renderer, "assets/fonts/Iosevka.ttf", {32, 64})

	// h := OMECORE.texture_create(
	// 	app,
	// 	app.renderer.texture_manager,
	// 	"assets/textures/frame.png",
	// 	"frame",
	// )
	// h := texture_atlas_create(app, app.renderer.texture_manager, {"assets/textures/highfive.jpg", "assets/textures/frame.png"}, "a")
	atlas := OMECORE.sprite_atlas_create_from_directory(app.renderer, "assets/textures/", "atlas")

	size: i32 = 128
	pixels: [dynamic]byte = make([dynamic]byte, 0, size * size * 4)
	defer delete(pixels)
	for i in 0 ..< size * size {
		x := i % size - size / 2
		y := i / size - size / 2
		if x * y > 0 do append(&pixels, 0, 0, 0, 255)
		if x * y <= 0 do append(&pixels, 252, 3, 236, 255)
	}

	td := OMECORE.TextureData {
		pixels   = raw_data(pixels),
		w        = size,
		h        = size,
		channels = 4,
		in_atlas = false,
		name     = "transparent",
	}
	OMECORE.texture_create_from_data(app.renderer, td)
	// setup user inut
	// app.key_callbacks[SDL.K_W] = proc(app: ^App) {rect.y += app.dt * 100}

	// build ui
	// OMECORE.app_init_ui(app)

	point_a := [2]f32{0, 0}
	point_b := [2]f32{100, 400}
	point_c := [2]f32{200, 300}
	point_d := [2]f32{150, 100}

	// start the event loop
	for !app.quit {
		OMECORE.app_process_events(app)

		point_a.x = (math.sin(app.time_manager.time) + 1) / 2 * width
		point_b.x = (math.sin(app.time_manager.time * 2) + 1) / 2 * width
		point_c.x = (math.sin(app.time_manager.time / 4) + 1) / 2 * width
		point_d.x = (math.sin(app.time_manager.time * 10) + 1) / 2 * width

		OMECORE.app_pre_render(app)
		OMECORE.render_line(
			app.renderer,
			[2]f32{0, 0},
			[2]f32{width, height},
			OMECORE.Color{255, 0, 0, 255},
			2,
		)
		OMECORE.render_segments(
			app.renderer,
			[][2]f32{point_a, point_b, point_c, point_d},
			OMECORE.Color{255, 255, 0, 255},
		)
		OMECORE.render_text(
			app.renderer,
			fmt.tprintf("%.2f", app.time_manager.fps),
			256,
			OMECORE.Rect{300, 300, 200, 200},
			OMECORE.Color{0, 0, 0, 255},
		)
		// OMECORE.render_text(
		// 	app.renderer,
		// 	fmt.tprintf("%.2f", app.time_manager.time),
		// 	256,
		// 	OMECORE.Rect{700, 300, 200, 200},
		// 	OMECORE.Color{0, 0, 0, 1},
		// )

		// OMECORE.render_text(
		// 	app.renderer,
		// 	fmt.tprintf("%.5f", app.time_manager.dt),
		// 	256,
		// 	OMECORE.Rect{500, 300, 200, 200},
		// 	OMECORE.Color{0, 0, 0, 1},
		// )
		OMECORE.render_texture(
			app.renderer,
			atlas,
			"panel",
			OMECORE.Rect{0, 0, 64, 64},
			OMECORE.Color{255, 255, 255, 255},
			// OMECORE.RectOffset{16, 16, 16, 16},
		)
		// OMECORE.render_texture(
		// 	app.renderer,
		// 	h,
		// 	OMECORE.Rect{100, 100, 100, 100},
		// 	OMECORE.Color{255, 255, 255, 255},
		// )
		// render_rect(app, Rect{200, 200, 100, 100}, Color{1, 0, 1, 1})


		// OMECORE.render_curve(
		// 	app.renderer,
		// 	{{25, 35}, {500, 500}, {1000, 100}},
		// 	OMECORE.Color{255, 0, 0, 255},
		// 	2,
		// )

		OMECORE.app_render(app)
		OMECORE.app_submit(app)

		free_all(context.temp_allocator)
	}
}
