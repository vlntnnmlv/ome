package ome

import "core:log"
import "core:os"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl3"

Renderer :: struct {
	device:          ^MTL.Device,
	command_q:       ^MTL.CommandQueue,
	pipeline_state:  ^MTL.RenderPipelineState,
	swapchain:       ^CA.MetalLayer,
	render_calls:    [dynamic]RenderCall,
	texture_manager: ^TextureManager,
	font:            Font,
	logical_size:    [2]i32,
	vertices:        GPUBuffer(Vertex),
	colors:          GPUBuffer(Color),
	uvs:             GPUBuffer(Uv),
	tex_ids:         GPUBuffer(TexID),
	modes:           GPUBuffer(Mode),
}

renderer_create :: proc(
	window: ^SDL.Window,
	logical_width, logical_height, pixel_width, pixel_height: i32,
) -> (
	^Renderer,
	bool,
) {
	device := MTL.CreateSystemDefaultDevice()

	if device == nil {
		log.errorf("Couldn't create default Metal device")
		return nil, false
	}

	argument_buffer_support := device->argumentBuffersSupport()
	if argument_buffer_support != .Tier2 {
		log.errorf("Argument buffers aren't supported")
		return nil, false
	}

	native_window := (^NS.Window)(
		SDL.GetPointerProperty(
			SDL.GetWindowProperties(window),
			SDL.PROP_WINDOW_COCOA_WINDOW_POINTER,
			nil,
		),
	)
	if native_window == nil {
		log.errorf("Couldn't get native window")
		return nil, false
	}

	swapchain := CA.MetalLayer.layer()
	swapchain->setDrawableSize(NS.Size{cast(NS.Float)pixel_width, cast(NS.Float)pixel_height})
	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	command_q := device->newCommandQueue()
	compile_options := NS.new(MTL.CompileOptions)

	shader_file, shader_file_load_error := os.read_entire_file_from_path(
		"assets/shaders/shader.metal",
		context.temp_allocator,
	)

	defer delete(shader_file, context.temp_allocator)
	if shader_file_load_error != nil {
		log.errorf(
			"Couldn't load shader files. Error: %v",
			os.error_string(shader_file_load_error),
		)
		return nil, false
	}

	program_library, lib_error := device->newLibraryWithSource(
		NS.String.alloc()->initWithOdinString(string(shader_file)),
		compile_options,
	)
	if lib_error != nil {
		log.errorf("Shader compilation failed. Error: %v", lib_error->localizedDescription())
		return nil, false
	}

	vertex_program := program_library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_program := program_library->newFunctionWithName(NS.AT("fragment_main"))

	if vertex_program == nil {
		log.errorf("Shader vertex function extraction failed.")
		return nil, false
	}

	if fragment_program == nil {
		log.errorf("Shader fragment function extraction failed.")
		return nil, false
	}

	pipeline_state_descriptor := NS.new(MTL.RenderPipelineDescriptor)
	pipeline_state_descriptor->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)
	pipeline_state_descriptor->setVertexFunction(vertex_program)
	pipeline_state_descriptor->setFragmentFunction(fragment_program)
	color_attachments := pipeline_state_descriptor->colorAttachments()->object(0)

	color_attachments->setBlendingEnabled(true)
	color_attachments->setRgbBlendOperation(.Add)
	color_attachments->setAlphaBlendOperation(.Add)
	color_attachments->setSourceRGBBlendFactor(.SourceAlpha)
	color_attachments->setSourceAlphaBlendFactor(.SourceAlpha)
	color_attachments->setDestinationRGBBlendFactor(.OneMinusSourceAlpha)
	color_attachments->setDestinationAlphaBlendFactor(.OneMinusSourceAlpha)

	pipeline_state, pipeline_error := device->newRenderPipelineState(pipeline_state_descriptor)
	if pipeline_error != nil {
		log.errorf("Pipeline creation failed. Error: %v", pipeline_error->localizedDescription())
		return nil, false
	}

	renderer := new(Renderer)

	renderer.device = device
	renderer.swapchain = swapchain
	renderer.command_q = command_q
	renderer.pipeline_state = pipeline_state
	renderer.render_calls = make([dynamic]RenderCall)
	renderer.texture_manager = texture_manager_create()
	renderer.logical_size = {logical_width, logical_height}
	renderer.vertices = gpu_buffer_create(Vertex, renderer.device)
	renderer.colors = gpu_buffer_create(Color, renderer.device)
	renderer.uvs = gpu_buffer_create(Uv, renderer.device)
	renderer.modes = gpu_buffer_create(Mode, renderer.device)
	renderer.tex_ids = gpu_buffer_create(TexID, renderer.device)

	texture_manager_init(renderer.texture_manager, renderer, fragment_program)


	return renderer, true
}

render_line :: proc(renderer: ^Renderer, start: [2]f32, end: [2]f32, color: Maybe(Color) = nil) {
	graphics_add_points(renderer, {start, end}, color)
}

render_segments :: proc(
	renderer: ^Renderer,
	points: [][2]f32,
	color: Maybe(Color) = nil,
	fill: bool = false,
) {
	graphics_add_points(renderer, points, color, fill)
}

render_rect :: proc(renderer: ^Renderer, rect: Rect, color: Maybe(Color) = nil) {
	graphics_add_quad(renderer, rect, color)
}

render_text :: proc(
	renderer: ^Renderer,
	text: string,
	font_size: u32,
	rect: Rect,
	color: Maybe(Color) = nil,
) {
	graphics_add_text(renderer, text, font_size, rect, color)
}

render_texture :: proc(
	renderer: ^Renderer,
	handle: TextureHandle,
	rect: Rect,
	color: Maybe(Color) = nil,
	slice_offset: Maybe(RectOffset) = nil,
) {
	graphics_add_texture(renderer, handle, rect, color, slice_offset)
}
