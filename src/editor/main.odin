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

move_camera :: proc(a: ^app.Engine) {
	if platform.key_down(.V) {
		render.renderer_get_camera2d(a.renderer, 1).zoom += 0.1
	}
	if platform.key_down(.C) {
		render.renderer_get_camera2d(a.renderer, 1).zoom -= 0.1
	}
	if platform.key_down(.W) {
		render.renderer_get_camera2d(a.renderer, 1).position.y -= 10 * a.clock.dt
	}
	if platform.key_down(.A) {
		render.renderer_get_camera2d(a.renderer, 1).position.x -= 10 * a.clock.dt
	}
	if platform.key_down(.S) {
		render.renderer_get_camera2d(a.renderer, 1).position.y += 10 * a.clock.dt
	}
	if platform.key_down(.D) {
		render.renderer_get_camera2d(a.renderer, 1).position.x += 10 * a.clock.dt
	}
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

	engine, engine_ok := app.engine_create("Ome", i32(width), i32(height))
	if !engine_ok {
		return
	}
	defer app.engine_destroy(engine)
	// ---------

	// --- RESOURCES ---
	library := engine.renderer.library

	font_handle, ferr := assets.library_load_font(
		library,
		"assets/fonts/Iosevka.ttf",
		"iosevka",
		{32, 64},
	)
	if ferr != .None {
		return
	}

	_, aerr := assets.library_load_atlas(library, "assets/textures/ui", "ui_atlas")
	if aerr != .None {
		return
	}
	_, aerr = assets.library_load_atlas(library, "assets/textures/player", "player_atlas")
	if aerr != .None {
		return
	}
	// ---------

	// --- UI ---
	screen_rect := core.Rect{0, 0, width, height}
	stage := ui.stage_create(library)
	defer ui.stage_destroy(stage)

	app.engine_add_event_handler(engine, stage, ui.stage_handle_event)

	scene_handle := ui.stage_add_scene(stage, "main", screen_rect)
	scene := ui.stage_get_scene(stage, scene_handle)
	scene.debug = true
	ui.stage_show_scene(stage, scene_handle)
	// ---------

	// --- SCRIPT ---
	vm, vm_ok := script.vm_create()
	if !vm_ok {
		return
	}
	defer script.vm_destroy(vm)
	// ---------

	// --- API ---
	host := api.host_create(engine.renderer, engine.window, &engine.clock, font_handle)
	defer api.host_destroy(host)
	api.host_register(host, vm)

	// ---------

	// --- BIND ---
	binder := bind.binder_create(stage, vm, library)
	defer bind.binder_destroy(binder)

	bind.binder_add_view(
		binder,
		bind.NO_LUA,
		"assets/ui/main.json",
		scene_handle,
		scene.root_handle,
	)

	// --- CAMERAS ---
	render.renderer_get_camera2d(engine.renderer, 1).zoom = 1

	render.renderer_set_camera3d(
		engine.renderer,
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
	for app.engine_next_frame(engine) {
		bind.binder_update(binder, engine.clock.dt)

		render.renderer_set_camera(engine.renderer, 1)
		bind.binder_draw(binder)

		ui.stage_render(stage, engine.renderer)
		render.renderer_set_camera(engine.renderer, 1)
		render.text(
			engine.renderer,
			fmt.tprint(engine.clock.fps),
			font_handle,
			64,
			{0, screen_rect.h / 2, 500, 500},
			core.Color{0, 0, 255, 255},
		)
	}
}
