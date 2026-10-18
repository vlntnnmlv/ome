package omegpu

import "ome:platform"
import vk "vendor:vulkan"

@(private)
SWAPCHAIN_FORMAT :: vk.Format.B8G8R8A8_SRGB

@(private)
Swapchain :: struct {
	handle:          vk.SwapchainKHR,
	format:          vk.Format,
	extent:          vk.Extent2D,
	images:          []vk.Image,
	views:           []vk.ImageView,
	render_finished: []vk.Semaphore,
	image_index:     u32,
}

@(private)
swapchain_create :: proc(
	device: ^Device,
	window_info: platform.WindowInfo,
	old: vk.SwapchainKHR,
) -> bool {
	swapchain := &device.swapchain
	swapchain^ = {}

	ok := false
	defer if !ok {
		swapchain_release(device, swapchain)
	}

	capabilities: vk.SurfaceCapabilitiesKHR
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical, device.surface, &capabilities)

	extent := capabilities.currentExtent
	if extent.width == max(u32) {
		extent = {u32(window_info.pixel_width), u32(window_info.pixel_height)}
	}
	extent.width = clamp(
		extent.width,
		capabilities.minImageExtent.width,
		capabilities.maxImageExtent.width,
	)
	extent.height = clamp(
		extent.height,
		capabilities.minImageExtent.height,
		capabilities.maxImageExtent.height,
	)

	image_count := capabilities.minImageCount + 1
	if capabilities.maxImageCount > 0 {
		image_count = min(image_count, capabilities.maxImageCount)
	}

	swapchain_info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = device.surface,
		minImageCount    = image_count,
		imageFormat      = SWAPCHAIN_FORMAT,
		imageColorSpace  = .SRGB_NONLINEAR,
		imageExtent      = extent,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
		imageSharingMode = .EXCLUSIVE,
		preTransform     = capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = .FIFO,
		clipped          = true,
		oldSwapchain     = old,
	}
	result := vk.CreateSwapchainKHR(device.handle, &swapchain_info, nil, &swapchain.handle)
	if !device_vulkan_ok(result, "vkCreateSwapchainKHR") {
		return false
	}
	swapchain.extent = extent

	count: u32
	vk.GetSwapchainImagesKHR(device.handle, swapchain.handle, &count, nil)
	swapchain.images = make([]vk.Image, count)
	vk.GetSwapchainImagesKHR(device.handle, swapchain.handle, &count, raw_data(swapchain.images))

	swapchain.views = make([]vk.ImageView, count)
	swapchain.render_finished = make([]vk.Semaphore, count)

	for image, i in swapchain.images {
		view_info := vk.ImageViewCreateInfo {
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = image,
			viewType = .D2,
			format = SWAPCHAIN_FORMAT,
			subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
		}
		result = vk.CreateImageView(device.handle, &view_info, nil, &swapchain.views[i])
		if !device_vulkan_ok(result, "vkCreateImageView") {
			return false
		}

		semaphore_info := vk.SemaphoreCreateInfo {
			sType = .SEMAPHORE_CREATE_INFO,
		}
		result = vk.CreateSemaphore(
			device.handle,
			&semaphore_info,
			nil,
			&swapchain.render_finished[i],
		)
		if !device_vulkan_ok(result, "vkCreateSemaphore") {
			return false
		}
	}

	ok = true
	return true
}

@(private)
swapchain_recreate :: proc(device: ^Device) -> bool {
	info := device.window_info
	if info.pixel_width == 0 || info.pixel_height == 0 {
		return false
	}

	vk.DeviceWaitIdle(device.handle)

	old := device.swapchain
	created := swapchain_create(device, info, old.handle)
	swapchain_release(device, &old)

	device.swapchain_dirty = !created
	return created
}

@(private)
swapchain_release :: proc(device: ^Device, swapchain: ^Swapchain) {
	for view in swapchain.views {
		vk.DestroyImageView(device.handle, view, nil)
	}
	for semaphore in swapchain.render_finished {
		vk.DestroySemaphore(device.handle, semaphore, nil)
	}
	vk.DestroySwapchainKHR(device.handle, swapchain.handle, nil)

	delete(swapchain.images)
	delete(swapchain.views)
	delete(swapchain.render_finished)
	swapchain^ = {}
}
