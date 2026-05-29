package ome

import "core:fmt"
import "core:mem"
import "core:strings"

Rect :: struct {
	x, y, w, h: f32,
}

RectOffset :: struct {
	left, right, top, bottom: f32,
}

Color :: distinct [4]f32
INVALID_COLOR :: Color{-1, -1, -1, -1}
TRANSPARENT_COLOR :: Color{0, 0, 0, 0}

UIPanelHandle :: distinct u32

UIPanelFillType :: enum {
	START,
	END,
	FILL,
}

UIPanelSize :: struct {
	horizontal_fill: UIPanelFillType,
	horizontal_size: f32,
	vertical_fill:   UIPanelFillType,
	vertical_size:   f32,
}

UIPanel :: struct {
	parent_handle:    Maybe(UIPanelHandle),
	children_handles: [dynamic]UIPanelHandle,
	rect:             Rect,
	world_rect:       Rect,
	size:             UIPanelSize,
	padding:          RectOffset,
	margin:           RectOffset,
	color:            Color,
	spec:             UIPanelSpec,
}

UIContext :: struct {
	arena:       mem.Dynamic_Pool,
	panels:      [dynamic]^UIPanel,
	root_handle: UIPanelHandle,
}

ui_context_init :: proc(ui_context: ^UIContext) {
	mem.dynamic_pool_init(&ui_context.arena)
	ui_context.panels = make([dynamic]^UIPanel)
}

ui_context_free :: proc(ui_context: ^UIContext) {
	delete(ui_context.panels)
	mem.dynamic_pool_destroy(&ui_context.arena)
}

@(private = "file")
ui_context_create_panel :: proc(
	ui_context: ^UIContext,
	parent_handle: Maybe(UIPanelHandle),
	rect: Rect,
	spec: UIPanelSpec,
	size: UIPanelSize = {.FILL, 0, .FILL, 0},
	color: Color = INVALID_COLOR,
) -> UIPanelHandle {
	handle := UIPanelHandle(len(ui_context.panels))

	panel := new(UIPanel, mem.dynamic_pool_allocator(&ui_context.arena))

	panel.parent_handle = parent_handle
	panel.rect = rect
	panel.spec = spec
	panel.size = size
	panel.color = color

	if parent_handle, ok := parent_handle.?; ok {
		parent := ui_context.panels[parent_handle]
		append(&parent.children_handles, handle)
	}

	append(&ui_context.panels, panel)

	return UIPanelHandle(len(ui_context.panels) - 1)
}

UIText :: struct {
	builder:   ^strings.Builder, // TODO: Maybe use array with predefined size
	font_size: u16, // TODO: use
}

UIStackOrientation :: enum {
	VERTICAL,
	HORIZONTAL,
}

UIStack :: struct {
	orientation: UIStackOrientation,
	spacing:     f32,
}

UIPanelSpec :: union {
	UIText,
	UIStack,
}

ui_create_panel :: proc(
	ui_context: ^UIContext,
	parent: Maybe(UIPanelHandle),
	rect: Rect,
	size: UIPanelSize = {.FILL, 0, .FILL, 0},
	color: Color = INVALID_COLOR,
) -> UIPanelHandle {
	panel_handle := ui_context_create_panel(ui_context, parent, rect, nil, size, color)
	return panel_handle
}

ui_create_text :: proc(
	ui_context: ^UIContext,
	parent: UIPanelHandle,
	rect: Rect,
	text: string,
	size: UIPanelSize = {.FILL, 0, .FILL, 0},
	color: Color = INVALID_COLOR,
) -> UIPanelHandle {
	ui_text := UIText {
		builder = new(strings.Builder),
	}
	strings.builder_init(ui_text.builder)
	fmt.sbprint(ui_text.builder, text)

	text_handle := ui_context_create_panel(ui_context, parent, rect, ui_text, size, color)
	return text_handle
}

ui_create_stack :: proc(
	ui_context: ^UIContext,
	parent: UIPanelHandle,
	rect: Rect,
	orientation: UIStackOrientation,
	spacing: f32 = 0,
	size: UIPanelSize = {.FILL, 0, .FILL, 0},
	color: Color = INVALID_COLOR,
) -> UIPanelHandle {
	return ui_context_create_panel(
		ui_context,
		parent,
		rect,
		UIStack{orientation, spacing},
		size,
		color,
	)
}

ui_set_text :: proc(ui_context: ^UIContext, handle: UIPanelHandle, text: string) {
	panel := ui_context.panels[handle]
	if ui_text, ok := &panel.spec.(UIText); ok {
		fmt.sbprint(ui_text.builder, text)
	}
}

ui_remove_panel :: proc(ui_context: ^UIContext, handle: UIPanelHandle) {
	panel := ui_context.panels[handle]

	if len(panel.children_handles) != 0 {
		for child_handle in panel.children_handles {
			ui_remove_panel(ui_context, child_handle)
		}
	}

	#partial switch spec in panel.spec {
	case UIText:
		strings.builder_destroy(spec.builder)
	}

	if parent_handle, ok := panel.parent_handle.?; ok {
		parent := ui_context.panels[parent_handle]
		for child_handle, i in parent.children_handles {
			if child_handle == handle {
				ordered_remove(&parent.children_handles, i)
				break
			}
		}
	}

	free(panel, mem.dynamic_pool_allocator(&ui_context.arena))

}

ui_remove_children :: proc(ui_context: ^UIContext, handle: UIPanelHandle) {
	panel := ui_context.panels[handle]
	for child_handle in panel.children_handles {
		ui_remove_panel(ui_context, child_handle)
	}
}

ui_validate :: proc(ui_context: ^UIContext, root_handle: UIPanelHandle) {
	panel := ui_context.panels[root_handle]
	// parent: ^UIPanel
	// if parent_handle, ok := panel.parent_handle.?; ok {
	// 	parent = ui_context.panels[parent_handle]
	// }

	// parent_content_rect := shrink(parent.rect, parent.padding)

	#partial switch spec in panel.spec {
	case UIStack:
		children_count: f32 = cast(f32)len(panel.children_handles)
		child_width: f32 = 0
		child_height: f32 = 0
		switch spec.orientation {
		case .VERTICAL:
			child_width = panel.rect.w
			child_height = (panel.rect.h - spec.spacing * (children_count - 1)) / children_count
		case .HORIZONTAL:
			child_width = (panel.rect.w - spec.spacing * (children_count - 1)) / children_count
			child_height = panel.rect.h
		}

		for child_handle, i in panel.children_handles {
			child := ui_context.panels[child_handle]
			child.rect.w = child_width
			child.rect.h = child_height
			switch spec.orientation {
			case .VERTICAL:
				child.rect.y = cast(f32)i * (child_height + spec.spacing)
			case .HORIZONTAL:
				child.rect.x = cast(f32)i * (child_width + spec.spacing)
			}
		}
	}

	if parent_handle, ok := panel.parent_handle.?; ok {
		parent := ui_context.panels[parent_handle]

		if parent.spec == nil {
			switch panel.size.horizontal_fill {
			case .START:
				panel.rect.x = 0
				panel.rect.w = panel.size.horizontal_size
			case .END:
				panel.rect.x = parent.rect.w - panel.size.horizontal_size
				panel.rect.w = panel.size.horizontal_size
			case .FILL:
				panel.rect.x = 0
				panel.rect.w = parent.rect.w
			}

			switch panel.size.vertical_fill {
			case .START:
				panel.rect.y = 0
				panel.rect.h = panel.size.vertical_size
			case .END:
				panel.rect.y = parent.rect.h - panel.size.vertical_size
				panel.rect.h = panel.size.vertical_size
			case .FILL:
				panel.rect.y = 0
				panel.rect.h = parent.rect.h
			}
		}
	}

	panel.world_rect.w = panel.rect.w
	panel.world_rect.h = panel.rect.h

	if parent_handle, ok := panel.parent_handle.?; ok {
		parent := ui_context.panels[parent_handle]
		panel.world_rect.x = parent.world_rect.x + panel.rect.x
		panel.world_rect.y = parent.world_rect.y + panel.rect.y
	}

	for child_handle in panel.children_handles {
		ui_validate(ui_context, child_handle)
	}
}

app_add_ui_panel :: proc(window: ^App, ui_context: ^UIContext, handle: UIPanelHandle) {
	// panel := ui_context.panels[handle]
	// switch spec in panel.spec {
	// case UIText:
	// 	graphics_add_text(
	// 		window,
	// 		panel.world_rect,
	// 		strings.to_string(spec.builder^),
	// 		panel.world_rect.x,
	// 		panel.world_rect.y,
	// 		panel.color,
	// 	)
	// 	strings.builder_reset(spec.builder)
	// case UIStack:
	// case nil:
	// 	graphics_add_quad(panel.world_rect, panel.color)
	// }
	// for child in panel.children_handles {
	// 	app_add_ui_panel(window, ui_context, child)
	// }
}
