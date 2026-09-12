package omeeditor

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

import "ome:app"
import "ome:core"
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

move_camera :: proc(a: ^app.App) {
	if platform.key_down(.V) do render.get_camera_2d(a.renderer, 1).zoom += 0.1
	if platform.key_down(.C) do render.get_camera_2d(a.renderer, 1).zoom -= 0.1
	if platform.key_down(.W) do render.get_camera_2d(a.renderer, 1).position.y -= 10 * a.time_manager.dt
	if platform.key_down(.A) do render.get_camera_2d(a.renderer, 1).position.x -= 10 * a.time_manager.dt
	if platform.key_down(.S) do render.get_camera_2d(a.renderer, 1).position.y += 10 * a.time_manager.dt
	if platform.key_down(.D) do render.get_camera_2d(a.renderer, 1).position.x += 10 * a.time_manager.dt
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

	a, ok := app.create("Ome", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app.close(a)

	// resources
	assets := a.renderer.assets

	font_handle, ferr := resources.load_font(assets, "assets/fonts/Iosevka.ttf", {32, 64})
	assert(ferr == resources.FontError.None)

	atlas_handle, aerr := resources.load_atlas(assets, "assets/textures/ui", "ui_atlas")
	assert(aerr == resources.AtlasError.None)

	// create UI
	screen_rect := core.Rect{0, 0, width, height}
	ui_instance := ui.create()
	defer ui.delete(&ui_instance)

	scene_handle := ui.add_scene(&ui_instance, screen_rect, "main")
	scene := ui.get_scene(&ui_instance, scene_handle)
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

	render.get_camera_2d(a.renderer, 1).zoom = 1

	render.set_camera_3d(
		a.renderer,
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

	// a.key_callbacks[.D] = proc(a: ^app.App) {move_camera(a, .D)}

	// start the event loop
	for app.frame(a) {
		render.set_camera(a.renderer, 2)
		move_camera(a)
		render.cube(a.renderer, {0, 0, 0}, 1, core.Color{0, 255, 0, 255})
		render.set_camera(a.renderer, 1)
		render.quad(a.renderer, {400, 400, 30, 30}, core.Color{244, 244, 244, 255})
		render.set_camera(a.renderer, 0)

		ui.scene_render(a.renderer, scene)
		render.text(
			a.renderer,
			fmt.tprint(a.time_manager.dt),
			font_handle,
			77,
			{100, 100, 500, 500},
			core.Color{0, 0, 255, 255},
		)
	}
}
