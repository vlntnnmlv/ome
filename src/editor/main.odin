package omeeditor

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

import "ome:api"
import "ome:app"
import "ome:assets"
import "ome:bind"
import "ome:core"
import "ome:platform"
import "ome:render"
import "ome:script"
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

move_camera :: proc(a: ^app.Instance) {
	if platform.key_down(.V) do render.get_camera_2d(a.renderer, 1).zoom += 0.1
	if platform.key_down(.C) do render.get_camera_2d(a.renderer, 1).zoom -= 0.1
	if platform.key_down(.W) do render.get_camera_2d(a.renderer, 1).position.y -= 10 * a.clock.dt
	if platform.key_down(.A) do render.get_camera_2d(a.renderer, 1).position.x -= 10 * a.clock.dt
	if platform.key_down(.S) do render.get_camera_2d(a.renderer, 1).position.y += 10 * a.clock.dt
	if platform.key_down(.D) do render.get_camera_2d(a.renderer, 1).position.x += 10 * a.clock.dt
}

main :: proc() {
	// --- LEAKS TRACKING ---
	tracked_allocator, tracking_allocator := track_start(context.allocator)
	context.allocator = tracked_allocator

	defer track_finish(tracking_allocator)

	opts: bit_set[runtime.Logger_Option] = {.Level}
	context.logger = log.create_console_logger(opt = opts)
	defer log.destroy_console_logger(context.logger)
	// ---------

	// --- WINDOW & APP ---
	width: f32 = 1080
	height: f32 = 720

	app_instance, ok := app.instance("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app.destroy(app_instance)
	// ---------

	// --- RESOURCES ---
	assets_instance := app_instance.renderer.assets

	font_handle, ferr := assets.load_font(
		assets_instance,
		"assets/fonts/Iosevka.ttf",
		"iosevka",
		{32, 64},
	)
	assert(ferr == assets.FontError.None)

	_, aerr := assets.load_atlas(assets_instance, "assets/textures/ui", "ui_atlas")
	assert(aerr == assets.AtlasError.None)
	_, aerr = assets.load_atlas(assets_instance, "assets/textures/player", "player_atlas")
	assert(aerr == assets.AtlasError.None)
	// ---------

	// --- UI ---
	screen_rect := core.Rect{0, 0, width, height}
	ui_instance := ui.instance()
	defer ui.destroy(&ui_instance)

	app.add_event_handler(app_instance, &ui_instance, ui.handle_event)

	scene_handle := ui.add_scene(&ui_instance, screen_rect, "main")
	ui.show_scene(&ui_instance, scene_handle)
	// ---------

	// --- SCRIPT ---
	script_instance, script_ok := script.instance()
	if !script_ok do return
	defer script.destroy(script_instance)

	scene := ui.get_scene(&ui_instance, scene_handle)
	scene.is_debug = true
	// ---------

	// --- API ---
	api_instance := api.instance(
		app_instance.renderer,
		app_instance.window,
		&app_instance.clock,
		font_handle,
	)
	defer api.destroy(api_instance)
	api.register(api_instance, script_instance)

	// ---------

	// --- BIND ---
	bind_instance := bind.instance(&ui_instance, script_instance, assets_instance)
	defer bind.destroy(bind_instance)

	bind.add_view(
		bind_instance,
		"assets/ui/main.lua",
		"assets/ui/main.json",
		scene_handle,
		scene.root_handle,
	)

	// --- CAMERAS ---
	render.get_camera_2d(app_instance.renderer, 1).zoom = 1

	render.set_camera_3d(
		app_instance.renderer,
		2,
		core.Camera3D {
			position = {3, 3, 5},
			target = {0, 0, 0},
			up = {0, 1, 0},
			fov_y = math.to_radians_f32(60),
			near = 0.1,
			far = 100,
			viewport = {0, 0, width, height},
		},
	)
	// ---------


	// --- LOOP ---
	for app.frame(app_instance) {
		bind.update(bind_instance, app_instance.clock.dt)

		render.set_camera(app_instance.renderer, 1)
		bind.draw(bind_instance)

		// move_camera(app_instance)
		// render.cube(app_instance.renderer, {0, 0, 0}, 1, core.Color{0, 255, 0, 255})
		// render.set_camera(app_instance.renderer, 1)
		// render.quad(app_instance.renderer, {400, 400, 30, 30}, core.Color{244, 244, 244, 255})
		// render.set_camera(app_instance.renderer, 0)

		ui.render(app_instance.renderer, &ui_instance)
		render.text(
			app_instance.renderer,
			fmt.tprint(app_instance.clock.fps),
			font_handle,
			77,
			{0, screen_rect.h, 500, 500},
			core.Color{0, 0, 255, 255},
		)
	}
}
