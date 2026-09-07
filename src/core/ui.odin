package ome

import SDL "vendor:sdl3"

UIPanelHandle :: distinct i32
ROOT_HANDLE: UIPanelHandle : 0
EMPTY_HANDLE: UIPanelHandle : -1

UISpec :: union {
	UIPanelSpec,
	UIImageSpec,
	UITextSpec,
}

UIPanelSpec :: struct {
	color: Color,
}

UIImageSpec :: struct {
	using panel:    UIPanelSpec,
	texture_handle: TextureHandle,
	slice_offset:   RectOffset,
}

UITextSpec :: struct {
	using panel: UIPanelSpec,
	text:        string,
	font_size:   u32,
}

UIPanel :: struct {
	handle:   UIPanelHandle,
	rect:     Rect,
	spec:     UISpec,
	children: [dynamic]UIPanelHandle,
	parent:   UIPanelHandle,
	hovered:  bool,
}

UIManager :: struct {
	panels:      [dynamic]UIPanel,
	root_handle: UIPanelHandle,
	next_handle: UIPanelHandle,
}

ui_manager_get_new_handle :: proc(ui_manager: ^UIManager) -> UIPanelHandle {
	handle := ui_manager.next_handle
	ui_manager.next_handle += 1
	return handle
}

ui_manager_create :: proc(rect: Rect) -> UIManager {
	root_panel := UIPanel {
		handle   = ROOT_HANDLE,
		rect     = rect,
		children = make([dynamic]UIPanelHandle),
		parent   = EMPTY_HANDLE,
	}

	panels := make([dynamic]UIPanel)
	append(&panels, root_panel)

	ui_manager := UIManager {
		panels      = panels,
		root_handle = ROOT_HANDLE,
		next_handle = ROOT_HANDLE + 1,
	}

	return ui_manager
}

ui_manager_delete :: proc(ui_manager: ^UIManager) {
	ui_panel_delete(ui_manager, ui_manager.panels[ui_manager.root_handle])
	delete(ui_manager.panels)
}

ui_panel_delete :: proc(ui_manager: ^UIManager, ui_panel: UIPanel) {
	for child in ui_panel.children {
		ui_panel_delete(ui_manager, ui_manager.panels[child])
	}

	delete(ui_panel.children)
}

ui_manager_process_event :: proc(ui_manager: ^UIManager, e: SDL.Event) {
	ui_panel_process_event(ui_manager.root_handle, ui_manager, e)
}

ui_manager_create_panel :: proc(
	ui_manager: ^UIManager,
	rect: Rect,
	parent: UIPanelHandle = ROOT_HANDLE,
	spec: UISpec = UIPanelSpec{},
) -> UIPanelHandle {
	world_rect := rect
	if parent != EMPTY_HANDLE {
		world_rect.x += ui_manager.panels[parent].rect.x
		world_rect.y += ui_manager.panels[parent].rect.y
	}

	ui_panel := UIPanel {
		handle   = ui_manager_get_new_handle(ui_manager),
		rect     = world_rect,
		children = make([dynamic]UIPanelHandle),
		parent   = parent,
		spec     = spec,
	}

	append(&ui_manager.panels, ui_panel)
	append(&ui_manager.panels[parent].children, ui_panel.handle)

	return ui_panel.handle
}

ui_panel_process_event :: proc(
	ui_panel_handle: UIPanelHandle,
	ui_manager: ^UIManager,
	e: SDL.Event,
) -> bool {
	if e.type != .MOUSE_MOTION do return false

	panel := &ui_manager.panels[ui_panel_handle]
	child_catched := false
	for child in panel.children {
		child_catched = ui_panel_process_event(child, ui_manager, e)
	}

	panel.hovered = !child_catched && contains(panel.rect, {e.motion.x, e.motion.y})
	return panel.hovered
}

ui_panel_render :: proc(
	renderer: ^Renderer,
	ui_manager: ^UIManager,
	ui_panel_handle: UIPanelHandle,
) {
	panel := ui_manager.panels[ui_panel_handle]
	color := Color{255, 0, 0, 255}
	if panel.hovered do color = Color{0, 255, 0, 255}

	render_quad(renderer, panel.rect, color, 1, false)
	switch spec in panel.spec {
	case UIPanelSpec:
		break
	case UITextSpec:
		render_text(renderer, spec.text, spec.font_size, panel.rect, spec.color)
	case UIImageSpec:
		render_texture(renderer, spec.texture_handle, panel.rect, spec.color)
	}

	for child in ui_manager.panels[ui_panel_handle].children {
		ui_panel_render(renderer, ui_manager, child)
	}
}

ui_manager_render :: proc(ui_manager: ^UIManager, renderer: ^Renderer) {
	ui_panel_render(renderer, ui_manager, ui_manager.root_handle)
}
