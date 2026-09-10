package omeeditor

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

import SDL "vendor:sdl3"

import "ome:core"
import "ome:ui"

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

move_camera :: proc(app: ^core.App, key: SDL.Keycode) {
	switch key {
	case SDL.K_V:
		core.renderer_get_camera_2d(app.renderer, 1).zoom += 0.1
	case SDL.K_C:
		core.renderer_get_camera_2d(app.renderer, 1).zoom -= 0.1
	case SDL.K_W:
		core.renderer_get_camera_2d(app.renderer, 1).position.y -= 5
	case SDL.K_A:
		core.renderer_get_camera_2d(app.renderer, 1).position.x -= 5
	case SDL.K_S:
		core.renderer_get_camera_2d(app.renderer, 1).position.y += 5
	case SDL.K_D:
		core.renderer_get_camera_2d(app.renderer, 1).position.x += 5
	}
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

	app, ok := core.app_create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer core.app_close(app)

	// load assets
	font: ^core.Font = new(core.Font)
	defer {
		core.font_delete(font)
		free(font)
	}

	core.font_load(font, app.renderer.texture_manager, "assets/fonts/Iosevka.ttf", {32, 64})
	atlas := core.sprite_atlas_create(app.renderer, "assets/textures/", "main_atlas")
	defer core.sprite_atlas_destroy(&atlas)

	// create UI
	screen_rect := core.Rect{0, 0, width, height}
	manager := ui.manager_create()
	defer ui.manager_delete(&manager)

	scene_handle := ui.manager_add_scene(&manager, screen_rect, "main")
	scene := core.handle_map_get(manager.scenes, scene_handle)
	ui.scene_add_panel(
		scene,
		scene.root_handle,
		"img",
		{width / 2 - 50, height / 2 - 50, 100, 100},
		ui.ImageSpec {
			color = core.Color{255, 255, 255, 255},
			texture_handle = atlas.handle,
			slice_offset = {0, 0, 0, 0},
		},
	)

	core.renderer_get_camera_2d(app.renderer, 1).zoom = 1
	app.renderer.cameras[2] = core.Camera3D {
		position = {3, 3, 5},
		target   = {0, 0, 0},
		up       = {0, 1, 0},
		fov_y    = math.to_radians_f32(60),
		near     = 0.1,
		far      = 100,
		viewport = {0, 0, width, height},
	}

	app.key_callbacks[SDL.K_V] = proc(app: ^core.App) {move_camera(app, SDL.K_V)}
	app.key_callbacks[SDL.K_C] = proc(app: ^core.App) {move_camera(app, SDL.K_C)}
	app.key_callbacks[SDL.K_W] = proc(app: ^core.App) {move_camera(app, SDL.K_W)}
	app.key_callbacks[SDL.K_A] = proc(app: ^core.App) {move_camera(app, SDL.K_A)}
	app.key_callbacks[SDL.K_S] = proc(app: ^core.App) {move_camera(app, SDL.K_S)}
	app.key_callbacks[SDL.K_D] = proc(app: ^core.App) {move_camera(app, SDL.K_D)}

	// start the event loop
	for !app.quit {
		core.app_process_events(app)

		core.app_pre_render(app)

		core.renderer_set_camera(app.renderer, 2)
		core.render_cube(app.renderer, {0, 0, 0}, 1, core.Color{0, 255, 0, 255})
		core.renderer_set_camera(app.renderer, 1)
		core.render_quad(app.renderer, {400, 400, 30, 30}, core.Color{244, 244, 244, 255})
		core.renderer_set_camera(app.renderer, 0)

		ui.scene_render(app.renderer, scene)
		core.render_text(
			app.renderer,
			"HeLLO",
			font,
			32,
			{100, 100, 500, 500},
			core.Color{0, 0, 255, 255},
		)

		core.app_render(app)
		core.app_submit(app)

		free_all(context.temp_allocator)
	}
}
