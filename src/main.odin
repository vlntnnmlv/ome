package ome

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

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

	app, ok := app_create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app_close(app)

	// load assets
	assets_load_font(app.renderer, "assets/fonts/Iosevka.ttf", {32, 64})

	// h := texture_create(app, app.texture_manager, "assets/textures/frame.png")

	// setup user inut
	// app.key_callbacks[SDL.K_W] = proc(app: ^App) {rect.y += app.dt * 100}

	// build ui
	app_init_ui(app)

	point_a := [2]f32{0, 0}
	point_b := [2]f32{100, 400}
	point_c := [2]f32{200, 300}
	point_d := [2]f32{150, 100}

	// start the event loop
	for !app.quit {
		app_process_events(app)

		point_a.x = (math.sin(app.time_manager.time) + 1) / 2 * width
		point_b.x = (math.sin(app.time_manager.time * 2) + 1) / 2 * width
		point_c.x = (math.sin(app.time_manager.time / 4) + 1) / 2 * width
		point_d.x = (math.sin(app.time_manager.time * 10) + 1) / 2 * width

		app_pre_render(app)
		render_line(app.renderer, [2]f32{0, 0}, [2]f32{width, height}, Color{1, 0, 0, 1})
		render_segments(
			app.renderer,
			[][2]f32{point_a, point_b, point_c, point_d},
			Color{1, 1, 0, 1},
		)
		render_text(
			app.renderer,
			fmt.tprintf("%.2f", app.time_manager.fps),
			256,
			Rect{300, 300, 200, 200},
			Color{0, 0, 0, 1},
		)
		render_text(
			app.renderer,
			fmt.tprintf("%.2f", app.time_manager.time),
			256,
			Rect{700, 300, 200, 200},
			Color{0, 0, 0, 1},
		)

		render_text(
			app.renderer,
			fmt.tprintf("%.5f", app.time_manager.dt),
			256,
			Rect{500, 300, 200, 200},
			Color{0, 0, 0, 1},
		)
		// render_texture(app, h, Rect{0, 0, 100, 100}, Color{1, 1, 1, 1}, RectOffset{16, 16, 16, 16})
		// render_texture(app, h, Rect{100, 100, 100, 100}, Color{1, 1, 1, 1})
		// render_rect(app, Rect{200, 200, 100, 100}, Color{1, 0, 1, 1})

		app_render(app)
		app_submit(app)

		free_all(context.temp_allocator)
	}
}
