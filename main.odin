package ome

import "core:fmt"
import "core:time"

UIOrderBook :: struct {
	root:       UIPanelHandle,
	bids:       UIPanelHandle,
	asks:       UIPanelHandle,
	bids_count: UIPanelHandle,
	asks_count: UIPanelHandle,
}

ui_create_orderbook :: proc(
	ui_context: ^UIContext,
	root: UIPanelHandle,
	rect: Rect,
) -> ^UIOrderBook {
	view := new(UIOrderBook)

	view.root = ui_create_stack(
		ui_context,
		root,
		rect,
		.HORIZONTAL,
		5,
		{.FILL, 0, .FILL, 0},
		TRANSPARENT_COLOR,
	)

	view.bids = ui_create_stack(ui_context, view.root, Rect{}, .VERTICAL, 5)
	view.asks = ui_create_stack(ui_context, view.root, Rect{}, .VERTICAL, 5)

	view.bids_count = ui_create_text(
		ui_context,
		view.bids,
		Rect{},
		fmt.tprint("Bids:", 0),
		{.START, 0, .START, 0},
		Color{0, 0, 0, 1},
	)

	view.asks_count = ui_create_text(
		ui_context,
		view.asks,
		Rect{},
		fmt.tprint("Asks:", 0),
		{.START, 0, .START, 0},
		Color{0, 0, 0, 1},
	)

	return view
}

OrderbookViewSync :: struct {
	ui_context: ^UIContext,
	orderbook:  ^OrderBook,
	view:       ^UIOrderBook,
}

orderbook_sync :: proc(sync: ^OrderbookViewSync) {
	ui_set_text(
		sync.ui_context,
		sync.view.bids_count,
		fmt.tprint("Bids:", sync.orderbook.bids_count),
	)

	ui_set_text(
		sync.ui_context,
		sync.view.asks_count,
		fmt.tprint("Asks:", sync.orderbook.asks_count),
	)

	if sync.orderbook.bids_count + sync.orderbook.asks_count == 0 {
		sync.ui_context.panels[sync.view.bids].rect.h = 0
		sync.ui_context.panels[sync.view.asks].rect.h = 0
		return
	}

	ui_remove_children(sync.ui_context, sync.view.bids)
	for _ in sync.orderbook.bids {
		ui_create_panel(
			sync.ui_context,
			sync.view.bids,
			Rect{},
			{.FILL, 0, .FILL, 0},
			Color{0.95, 0.2, 0.1, 1},
		)
	}

	ui_remove_children(sync.ui_context, sync.view.asks)
	for _ in sync.orderbook.asks {
		ui_create_panel(
			sync.ui_context,
			sync.view.asks,
			Rect{},
			{.FILL, 0, .FILL, 0},
			Color{0.2, 0.95, 0.1, 1},
		)
	}
}

rect: Rect
main :: proc() {
	// orderbook
	account_ids: [5]u64 = {0, 1, 2, 3, 4}
	orderbook := OrderBook{}

	orderbook_fill(&orderbook, &account_ids, 100)

	fmt.println("Bids count: ", orderbook.bids_count)
	fmt.println("Asks count: ", orderbook.asks_count)

	// window
	width: f32 = 1080
	height: f32 = 720

	ok := app_create("OME", cast(i32)width, cast(i32)height)
	if !ok do return
	defer app_close(app)

	// load assets
	assets_load_font("assets/Iosevka.ttf", {32, 64})

	h := texture_create(app.texture_manager, "assets/highfive.jpg")

	// setup user inut
	// app.key_callbacks[SDL.K_W] = proc(app: ^App) {rect.y += app.dt * 100}
	// app.key_callbacks[SDL.K_A] = proc(app: ^App) {rect.x -= app.dt * 100}
	// app.key_callbacks[SDL.K_S] = proc(app: ^App) {rect.y -= app.dt * 100}
	// app.key_callbacks[SDL.K_D] = proc(app: ^App) {rect.x += app.dt * 100}

	// build ui
	app_init_ui(app)

	// start the event loop
	for !app.quit {
		app_process_events(app)
		app_pre_render(app)

		render_line([2]f32{0, 0}, [2]f32{width, height}, Color{1, 0, 0, 1})
		render_segments([][2]f32{{0, 0}, {100, 400}, {200, 300}, {150, 100}}, Color{1, 1, 0, 1})
		render_rect(Rect{rect.x, rect.y, 100, 100}, Color{1, 1, 1, 1})
		render_text("Hello world!", 256, Rect{300, 300, 200, 200}, Color{0, 0, 0, 1})
		render_texture(h, Rect{50, 50, 200, 200})

		app_render(app)
		app_submit(app)

		time.sleep(100 * time.Millisecond)

		free_all(context.temp_allocator)
	}
}
