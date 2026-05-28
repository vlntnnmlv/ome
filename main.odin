package ome

main :: proc() {
	// window
	width: f32 = 1080
	height: f32 = 720

	ok := app_create("OME", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app_close(app)

	// load assets
	assets_load_font("assets/fonts/Iosevka.ttf", {32, 64})

	h := texture_create(app.texture_manager, "assets/textures/frame.png")

	// setup user inut
	// app.key_callbacks[SDL.K_W] = proc(app: ^App) {rect.y += app.dt * 100}

	// build ui
	app_init_ui(app)

	// start the event loop
	for !app.quit {
		app_process_events(app)
		app_pre_render(app)

		// render_line([2]f32{0, 0}, [2]f32{width, height}, Color{1, 0, 0, 1})
		// render_segments([][2]f32{{0, 0}, {100, 400}, {200, 300}, {150, 100}}, Color{1, 1, 0, 1})
		// render_rect(Rect{0, 0, 100, 100}, Color{1, 1, 1, 1})
		// render_text("Hello world!", 256, Rect{300, 300, 200, 200}, Color{0, 0, 0, 1})
		render_texture(h, Rect{0, 0, 100, 100}, Color{1, 1, 1, 1}, RectOffset{16, 16, 16, 16})
		render_texture(h, Rect{100, 100, 100, 100}, Color{1, 1, 1, 1})

		app_render(app)
		app_submit(app)

		free_all(context.temp_allocator)
	}
}
