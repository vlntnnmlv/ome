package omerender

import "ome:assets"
import "ome:core"
import "ome:gpu"
import "ome:platform"

Renderer :: struct {
	device:  ^gpu.Device,
	batch:   Batch,
	library: ^assets.Library,
}

renderer_create :: proc(
	device: ^gpu.Device,
	library: ^assets.Library,
	window_info: platform.WindowInfo,
) -> ^Renderer {
	renderer := new(Renderer)
	renderer.device = device
	renderer.library = library
	renderer.batch = batch_create(window_info)

	return renderer
}

renderer_begin :: proc(renderer: ^Renderer) -> bool {
	assets.library_flush(renderer.library)
	batch_clear(&renderer.batch)
	return gpu.device_begin(renderer.device)
}

renderer_flush :: proc(renderer: ^Renderer) {
	view_projections: [MAX_CAMERAS]matrix[4, 4]f32
	for camera, i in renderer.batch.cameras {
		view_projections[i] = core.camera_get_view_projection(camera)
	}
	gpu.frame_submit(
		renderer.device,
		renderer.batch.vertices[:],
		renderer.batch.calls[:],
		view_projections[:],
	)
}

renderer_present :: proc(renderer: ^Renderer) {
	gpu.device_present(renderer.device)
}

renderer_resize :: proc(renderer: ^Renderer, info: platform.WindowInfo) {
	gpu.device_resize(renderer.device, info)
	batch_resize(&renderer.batch, info)
}

renderer_set_camera :: proc(renderer: ^Renderer, index: u32) {
	assert(index < MAX_CAMERAS)
	renderer.batch.active_state.view = index
}

renderer_get_camera2d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera2D {
	return &renderer.batch.cameras[index].(core.Camera2D)
}

renderer_set_camera2d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera2D) {
	assert(index < MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

renderer_get_camera3d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera3D {
	return &renderer.batch.cameras[index].(core.Camera3D)
}

renderer_set_camera3d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera3D) {
	assert(index < MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

renderer_destroy :: proc(renderer: ^Renderer) {
	batch_destroy(&renderer.batch)
	free(renderer)
}
