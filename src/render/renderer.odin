package omerender

import "ome:assets"
import "ome:core"
import "ome:gpu"
import "ome:platform"

Renderer :: struct {
	device:  ^gpu.Device,
	batch:   gpu.Batch,
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
	renderer.batch = gpu.batch_create(device, window_info)
	return renderer
}

renderer_begin :: proc(renderer: ^Renderer) {
	assets.library_flush(renderer.library)
	gpu.device_begin(renderer.device)
	gpu.batch_clear(&renderer.batch)
}

renderer_flush :: proc(renderer: ^Renderer) {
	gpu.batch_flush(&renderer.batch, renderer.device)
}

renderer_present :: proc(renderer: ^Renderer) {
	gpu.device_present(renderer.device)
}

renderer_resize :: proc(renderer: ^Renderer, info: platform.WindowInfo) {
	gpu.device_resize(renderer.device, info)
	gpu.batch_resize(&renderer.batch, info)
}

renderer_set_camera :: proc(renderer: ^Renderer, index: u32) {
	gpu.batch_set_camera(&renderer.batch, index)
}

renderer_get_camera2d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera2D {
	return gpu.batch_get_camera2d(&renderer.batch, index)
}

renderer_set_camera2d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera2D) {
	assert(index < gpu.MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

renderer_get_camera3d :: proc(renderer: ^Renderer, index: u32) -> ^core.Camera3D {
	return gpu.batch_get_camera3d(&renderer.batch, index)
}

renderer_set_camera3d :: proc(renderer: ^Renderer, index: u32, camera: core.Camera3D) {
	assert(index < gpu.MAX_CAMERAS)
	renderer.batch.cameras[index] = camera
}

renderer_destroy :: proc(renderer: ^Renderer) {
	gpu.batch_destroy(&renderer.batch)
	free(renderer)
}
