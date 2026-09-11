package omeeditor

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

import "ome:app"
import "ome:core"
import "ome:core/gpu"
import "ome:core/handle_map"
import "ome:core/platform"
import "ome:core/render"
import "ome:core/resources"
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

move_camera :: proc(app: ^app.App) {
	if platform.key_down(.V) do gpu.renderer_get_camera_2d(app.renderer, 1).zoom += 0.1
	if platform.key_down(.C) do gpu.renderer_get_camera_2d(app.renderer, 1).zoom -= 0.1
	if platform.key_down(.W) do gpu.renderer_get_camera_2d(app.renderer, 1).position.y -= 5
	if platform.key_down(.A) do gpu.renderer_get_camera_2d(app.renderer, 1).position.x -= 5
	if platform.key_down(.S) do gpu.renderer_get_camera_2d(app.renderer, 1).position.y += 5
	if platform.key_down(.D) do gpu.renderer_get_camera_2d(app.renderer, 1).position.x += 5
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

	a, ok := app.app_create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app.app_close(a)

	// resources
	rsrcs := resources.create(a.renderer)
	defer
	{
		resources.delete(rsrcs)
		free(rsrcs)
	}

	font_handle, ferr := resources.load_font(rsrcs, "assets/fonts/Iosevka.ttf", {32, 64})
	assert(ferr == resources.FontError.None)

	atlas_handle, aerr := resources.load_atlas(rsrcs, "assets/textures/ui", "ui_atlas")
	assert(aerr == resources.AtlasError.None)

	// create UI
	screen_rect := core.Rect{0, 0, width, height}
	manager := ui.create()
	defer ui.delete(&manager)

	scene_handle := ui.add_scene(&manager, screen_rect, "main")
	scene := handle_map.get(manager.scenes, scene_handle)
	ui.scene_add_panel(
		scene,
		scene.root_handle,
		"img",
		{width / 2 - 50, height / 2 - 50, 100, 100},
		ui.ImageSpec {
			color = core.Color{255, 255, 255, 255},
			atlas_handle = atlas_handle,
			sprite_name = "frame",
			slice_offset = {8, 8, 8, 8},
		},
	)

	gpu.renderer_get_camera_2d(a.renderer, 1).zoom = 1
	a.renderer.cameras[2] = core.Camera3D {
		position = {3, 3, 5},
		target   = {0, 0, 0},
		up       = {0, 1, 0},
		fov_y    = math.to_radians_f32(60),
		near     = 0.1,
		far      = 100,
		viewport = {0, 0, width, height},
	}

	// a.key_callbacks[.V] = proc(a: ^app.App) {move_camera(a, .V)}
	// a.key_callbacks[.C] = proc(a: ^app.App) {move_camera(a, .C)}
	// a.key_callbacks[.W] = proc(a: ^app.App) {move_camera(a, .W)}
	// a.key_callbacks[.A] = proc(a: ^app.App) {move_camera(a, .A)}
	// a.key_callbacks[.S] = proc(a: ^app.App) {move_camera(a, .S)}
	// a.key_callbacks[.D] = proc(a: ^app.App) {move_camera(a, .D)}

	// start the event loop
	for !a.quit {
		app.app_process_events(a)
		move_camera(a)

		resources.flush(rsrcs)
		app.app_pre_render(a)

		gpu.renderer_set_camera(a.renderer, 2)
		render.cube(rsrcs, {0, 0, 0}, 1, core.Color{0, 255, 0, 255})
		gpu.renderer_set_camera(a.renderer, 1)
		render.quad(rsrcs, {400, 400, 30, 30}, core.Color{244, 244, 244, 255})
		gpu.renderer_set_camera(a.renderer, 0)

		ui.scene_render(rsrcs, scene)
		render.text(
			rsrcs,
			"HeLLO",
			font_handle,
			77,
			{100, 100, 500, 500},
			core.Color{0, 0, 255, 255},
		)

		app.app_render(a)
		app.app_submit(a)

		free_all(context.temp_allocator)
	}
}
