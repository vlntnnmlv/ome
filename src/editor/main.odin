package omeeditor

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"

import SDL "vendor:sdl3"

import OMECORE "../core"

track_start :: proc(allocator: mem.Allocator) -> (mem.Allocator, ^mem.Tracking_Allocator) {
	tracking_allocator: ^mem.Tracking_Allocator = new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, allocator)
	return mem.tracking_allocator(tracking_allocator), tracking_allocator
}

track_finish :: proc(tracking_allocator: ^mem.Tracking_Allocator) {
	if len(tracking_allocator.allocation_map) > 0 {
		fmt.eprintf("=== %v allocations not freed: ===\n", len(tracking_allocator.allocation_map))
		for _, entry in tracking_allocator.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}

	mem.tracking_allocator_destroy(tracking_allocator)
}

main :: proc() {
	// system
	tracked_allocator, tracking_allocator := track_start(context.allocator)
	context.allocator = tracked_allocator

	defer track_finish(tracking_allocator)

	opts: bit_set[runtime.Logger_Option] = {.Level}
	context.logger = log.create_console_logger(opt = opts)
	defer log.destroy_console_logger(context.logger)

	// window
	width: f32 = 1080
	height: f32 = 720

	app, ok := OMECORE.app_create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer OMECORE.app_close(app)

	// load assets
	OMECORE.assets_load_font(app.renderer, "assets/fonts/Iosevka.ttf", {32, 64})
	atlas := OMECORE.sprite_atlas_create(app.renderer, "assets/textures/", "main_atlas")
	defer OMECORE.sprite_atlas_destroy(&atlas)

	// create UI
	ui_manager: OMECORE.UIManager = OMECORE.ui_manager_create(OMECORE.Rect{0, 0, width, height})
	defer OMECORE.ui_manager_delete(&ui_manager)

	p := OMECORE.ui_manager_create_panel(
		&ui_manager,
		OMECORE.Rect{10, 10, 200, 200},
		0,
		OMECORE.UIImageSpec {
			texture_handle = atlas.handle,
			color = OMECORE.Color{255, 255, 255, 255},
		},
	)
	OMECORE.ui_manager_create_panel(&ui_manager, OMECORE.Rect{5, 5, 20, 20}, p)
	// OMECORE.ui_manager_create_panel(&ui_manager, OMECORE.Rect{100, 100, 250, 1200})

	app.renderer.cameras[1].zoom = 1

	app.key_callbacks[SDL.K_V] = proc(ctx: ^OMECORE.App) {ctx.renderer.cameras[1].zoom += 0.1}
	app.key_callbacks[SDL.K_C] = proc(ctx: ^OMECORE.App) {ctx.renderer.cameras[1].zoom -= 0.1}

	// start the event loop
	for !app.quit {
		OMECORE.app_process_events(app, &ui_manager)

		OMECORE.app_pre_render(app)

		OMECORE.renderer_set_camera(app.renderer, 1)
		OMECORE.render_quad(app.renderer, {400, 400, 30, 30}, OMECORE.Color{244, 244, 244, 255})
		OMECORE.renderer_set_camera(app.renderer, 0)
		OMECORE.ui_manager_render(&ui_manager, app.renderer)

		OMECORE.app_render(app)
		OMECORE.app_submit(app)

		free_all(context.temp_allocator)
	}
}
