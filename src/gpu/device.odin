package omegpu

import "base:runtime"
import "core:log"

import vk "vendor:vulkan"

import "ome:platform"

FRAMES_IN_FLIGHT :: GPU_BUFFERS_RING_SIZE

@(private)
VALIDATION :: #config(OME_VULKAN_VALIDATION, ODIN_DEBUG)

@(private)
FrameSlot :: struct {
	command_buffer:  vk.CommandBuffer,
	upload_buffer:   vk.CommandBuffer,
	fence:           vk.Fence,
	image_available: vk.Semaphore,
	staging:         BufferSlot,
}

Device :: struct {
	instance:          vk.Instance,
	debug_messenger:   vk.DebugUtilsMessengerEXT,
	log_context:       runtime.Context,
	surface:           vk.SurfaceKHR,
	physical:          vk.PhysicalDevice,
	handle:            vk.Device,
	queue:             vk.Queue,
	queue_family:      u32,
	command_pool:      vk.CommandPool,
	//
	swapchain:         Swapchain,
	swapchain_dirty:   bool,
	window_info:       platform.WindowInfo,
	clear_color:       vk.ClearColorValue,
	//
	vertex_set_layout: vk.DescriptorSetLayout,
	pipeline_layout:   vk.PipelineLayout,
	pipelines:         [TopologyClass]vk.Pipeline,
	//
	bind_table:        ^BindTable,
	uploads:           UploadQueue,
	vertex_ring:       Buffer(Vertex2D),
	//
	frames:            [FRAMES_IN_FLIGHT]FrameSlot,
	frame_slot_index:  int,
}

device_create :: proc(window: ^platform.Window, clear_color: [4]f64) -> (^Device, bool) {
	device := new(Device)
	device.window_info = window.info
	device.clear_color = vk.ClearColorValue {
		float32 = {f32(clear_color.r), f32(clear_color.g), f32(clear_color.b), f32(clear_color.a)},
	}

	ok := false
	defer if !ok {
		device_destroy(device)
	}

	if !device_create_instance(device) {
		return nil, false
	}

	surface, surface_ok := platform.window_create_surface(window, device.instance)
	if !surface_ok {
		return nil, false
	}
	device.surface = surface

	if !device_pick_physical(device) {
		return nil, false
	}
	if !device_create_logical(device) {
		return nil, false
	}
	if !device_create_frames(device) {
		return nil, false
	}
	if !swapchain_create(device, device.window_info, 0) {
		return nil, false
	}

	bind_table, bind_table_ok := bind_table_create(device)
	if !bind_table_ok {
		return nil, false
	}
	device.bind_table = bind_table

	if !pipelines_create(device) {
		return nil, false
	}

	vertex_ring, vertex_ring_ok := buffer_create(Vertex2D, device, {.STORAGE_BUFFER})
	if !vertex_ring_ok {
		return nil, false
	}
	device.vertex_ring = vertex_ring

	ok = true
	return device, true
}

@(private = "file")
device_create_instance :: proc(device: ^Device) -> bool {
	vk.load_proc_addresses_global(platform.vulkan_instance_proc_address())

	extensions := make([dynamic]cstring, context.temp_allocator)
	append(&extensions, ..platform.vulkan_instance_extensions())

	flags: vk.InstanceCreateFlags
	when ODIN_OS == .Darwin {
		append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
		flags += {.ENUMERATE_PORTABILITY_KHR}
	}
	when ODIN_OS == .Windows {
		// TODO:
	}

	layers := make([dynamic]cstring, context.temp_allocator)
	when VALIDATION {
		append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
		append(&layers, "VK_LAYER_KHRONOS_validation")
	}

	app_info := vk.ApplicationInfo {
		sType            = .APPLICATION_INFO,
		pApplicationName = "ome",
		pEngineName      = "ome",
		apiVersion       = vk.API_VERSION_1_3,
	}

	instance_info := vk.InstanceCreateInfo {
		sType                   = .INSTANCE_CREATE_INFO,
		flags                   = flags,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
		enabledLayerCount       = u32(len(layers)),
		ppEnabledLayerNames     = raw_data(layers),
	}

	result := vk.CreateInstance(&instance_info, nil, &device.instance)
	if !device_vulkan_ok(result, "vkCreateInstance") {
		return false
	}
	vk.load_proc_addresses_instance(device.instance)

	when VALIDATION {
		device.log_context = context
		messenger_info := vk.DebugUtilsMessengerCreateInfoEXT {
			sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			messageSeverity = {.WARNING, .ERROR},
			messageType     = {.GENERAL, .VALIDATION, .PERFORMANCE},
			pfnUserCallback = device_debug_callback,
			pUserData       = &device.log_context,
		}
		result = vk.CreateDebugUtilsMessengerEXT(
			device.instance,
			&messenger_info,
			nil,
			&device.debug_messenger,
		)
		if !device_vulkan_ok(result, "vkCreateDebugUtilsMessengerEXT") {
			return false
		}
	}

	return true
}

@(private = "file")
device_pick_physical :: proc(device: ^Device) -> bool {
	count: u32
	vk.EnumeratePhysicalDevices(device.instance, &count, nil)
	physical_devices := make([]vk.PhysicalDevice, count, context.temp_allocator)
	vk.EnumeratePhysicalDevices(device.instance, &count, raw_data(physical_devices))

	for physical_device in physical_devices {
		properties: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(physical_device, &properties)
		name := cstring(raw_data(properties.deviceName[:]))

		if properties.apiVersion < vk.API_VERSION_1_3 {
			log.warnf("gpu/device: skipping '%s', apiVersion < 1.3", name)
			continue
		}
		if !device_supports_requirements(physical_device) {
			log.warnf("gpu/device: skipping '%s', missing features or extensions", name)
			continue
		}

		family, family_ok := device_find_queue_family(physical_device, device.surface)
		if !family_ok {
			log.warnf("gpu/device: skipping '%s', no graphics+present queue", name)
			continue
		}

		device.physical = physical_device
		device.queue_family = family
		log.infof("gpu/device: using '%s'", name)
		return true
	}

	log.errorf("gpu/device: no suitable gpu found")
	return false
}

@(private = "file")
device_find_queue_family :: proc(
	physical_device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> (
	u32,
	bool,
) {
	count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &count, nil)
	families := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &count, raw_data(families))

	for family, i in families {
		present: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(physical_device, u32(i), surface, &present)
		if .GRAPHICS in family.queueFlags && present {
			return u32(i), true
		}
	}

	return 0, false
}

@(private = "file")
device_supports_requirements :: proc(physical_device: vk.PhysicalDevice) -> bool {
	features13 := vk.PhysicalDeviceVulkan13Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
	}
	features12 := vk.PhysicalDeviceVulkan12Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		pNext = &features13,
	}
	features := vk.PhysicalDeviceFeatures2 {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &features12,
	}
	vk.GetPhysicalDeviceFeatures2(physical_device, &features)

	has_features :=
		features13.dynamicRendering &&
		features13.synchronization2 &&
		features12.runtimeDescriptorArray &&
		features12.descriptorBindingPartiallyBound &&
		features12.descriptorBindingSampledImageUpdateAfterBind &&
		features12.descriptorBindingUpdateUnusedWhilePending &&
		features12.shaderSampledImageArrayNonUniformIndexing

	return(
		bool(has_features) &&
		device_has_extension(physical_device, vk.KHR_SWAPCHAIN_EXTENSION_NAME) &&
		device_has_extension(physical_device, vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME) \
	)
}

@(private = "file")
device_create_logical :: proc(device: ^Device) -> bool {
	features13 := vk.PhysicalDeviceVulkan13Features {
		sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
		dynamicRendering = true,
		synchronization2 = true,
	}
	features12 := vk.PhysicalDeviceVulkan12Features {
		sType                                        = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		pNext                                        = &features13,
		runtimeDescriptorArray                       = true,
		descriptorBindingPartiallyBound              = true,
		descriptorBindingSampledImageUpdateAfterBind = true,
		descriptorBindingUpdateUnusedWhilePending    = true,
		shaderSampledImageArrayNonUniformIndexing    = true,
	}
	features := vk.PhysicalDeviceFeatures2 {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &features12,
	}

	extensions := make([dynamic]cstring, context.temp_allocator)
	append(&extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME, vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME)
	if device_has_extension(device.physical, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME) {
		append(&extensions, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME)
	}

	priority: f32 = 1
	queue_info := vk.DeviceQueueCreateInfo {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		queueFamilyIndex = device.queue_family,
		queueCount       = 1,
		pQueuePriorities = &priority,
	}

	device_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &features,
		queueCreateInfoCount    = 1,
		pQueueCreateInfos       = &queue_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
	}

	result := vk.CreateDevice(device.physical, &device_info, nil, &device.handle)
	if !device_vulkan_ok(result, "vkCreateDevice") {
		return false
	}
	vk.load_proc_addresses_device(device.handle)
	vk.GetDeviceQueue(device.handle, device.queue_family, 0, &device.queue)

	return true
}

@(private = "file")
device_create_frames :: proc(device: ^Device) -> bool {
	pool_info := vk.CommandPoolCreateInfo {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.queue_family,
	}
	result := vk.CreateCommandPool(device.handle, &pool_info, nil, &device.command_pool)
	if !device_vulkan_ok(result, "vkCreateCommandPool") {
		return false
	}

	for &frame in device.frames {
		buffers: [2]vk.CommandBuffer
		allocate_info := vk.CommandBufferAllocateInfo {
			sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool        = device.command_pool,
			level              = .PRIMARY,
			commandBufferCount = len(buffers),
		}
		result = vk.AllocateCommandBuffers(device.handle, &allocate_info, &buffers[0])
		if !device_vulkan_ok(result, "vkAllocateCommandBuffers") {
			return false
		}
		frame.command_buffer = buffers[0]
		frame.upload_buffer = buffers[1]

		fence_info := vk.FenceCreateInfo {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED},
		}
		result = vk.CreateFence(device.handle, &fence_info, nil, &frame.fence)
		if !device_vulkan_ok(result, "vkCreateFence") {
			return false
		}

		semaphore_info := vk.SemaphoreCreateInfo {
			sType = .SEMAPHORE_CREATE_INFO,
		}
		result = vk.CreateSemaphore(device.handle, &semaphore_info, nil, &frame.image_available)
		if !device_vulkan_ok(result, "vkCreateSemaphore") {
			return false
		}
	}

	return true
}

device_resize :: proc(device: ^Device, window_info: platform.WindowInfo) {
	device.window_info = window_info
	device.swapchain_dirty = true
}

device_wait_idle :: proc(device: ^Device) {
	vk.DeviceWaitIdle(device.handle)
}

@(private)
device_has_extension :: proc(physical_device: vk.PhysicalDevice, extension: string) -> bool {
	count: u32
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
	properties := make([]vk.ExtensionProperties, count, context.temp_allocator)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, raw_data(properties))

	for &property in properties {
		if string(cstring(raw_data(property.extensionName[:]))) == extension {
			return true
		}
	}

	return false
}


@(private)
device_find_memory_type :: proc(
	physical_device: vk.PhysicalDevice,
	type_bits: u32,
	required: vk.MemoryPropertyFlags,
) -> (
	u32,
	bool,
) {
	properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &properties)
	for i in 0 ..< properties.memoryTypeCount {
		if type_bits & (1 << i) != 0 && properties.memoryTypes[i].propertyFlags >= required {
			return i, true
		}
	}
	return 0, false
}

@(private)
cmd_image_barrier :: proc(
	cmd: vk.CommandBuffer,
	image: vk.Image,
	old_layout, new_layout: vk.ImageLayout,
	src_stage: vk.PipelineStageFlags2,
	src_access: vk.AccessFlags2,
	dst_stage: vk.PipelineStageFlags2,
	dst_access: vk.AccessFlags2,
) {
	barrier := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		srcStageMask = src_stage,
		srcAccessMask = src_access,
		dstStageMask = dst_stage,
		dstAccessMask = dst_access,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
	}
	dependency := vk.DependencyInfo {
		sType                   = .DEPENDENCY_INFO,
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers    = &barrier,
	}
	vk.CmdPipelineBarrier2(cmd, &dependency)
}

device_begin :: proc(device: ^Device) -> bool {
	if device.swapchain_dirty && !swapchain_recreate(device) {
		return false
	}

	device.frame_slot_index = (device.frame_slot_index + 1) % FRAMES_IN_FLIGHT
	frame := &device.frames[device.frame_slot_index]

	vk.WaitForFences(device.handle, 1, &frame.fence, true, max(u64))
	result := vk.AcquireNextImageKHR(
		device.handle,
		device.swapchain.handle,
		max(u64),
		frame.image_available,
		0,
		&device.swapchain.image_index,
	)
	if result == .ERROR_OUT_OF_DATE_KHR {
		device.swapchain_dirty = true
		return false
	}
	if result == .SUBOPTIMAL_KHR {
		device.swapchain_dirty = true
	} else if !device_vulkan_ok(result, "vkAcquireNextImageKHR") {
		return false
	}

	vk.ResetFences(device.handle, 1, &frame.fence)

	bind_table_begin_frame(device.bind_table)

	cmd := frame.command_buffer
	vk.ResetCommandBuffer(cmd, {})
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	vk.BeginCommandBuffer(cmd, &begin_info)

	index := device.swapchain.image_index
	cmd_image_barrier(
		cmd,
		device.swapchain.images[index],
		.UNDEFINED,
		.COLOR_ATTACHMENT_OPTIMAL,
		src_stage = {.COLOR_ATTACHMENT_OUTPUT},
		src_access = {},
		dst_stage = {.COLOR_ATTACHMENT_OUTPUT},
		dst_access = {.COLOR_ATTACHMENT_WRITE},
	)

	color := vk.RenderingAttachmentInfo {
		sType = .RENDERING_ATTACHMENT_INFO,
		imageView = device.swapchain.views[index],
		imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
		loadOp = .CLEAR,
		storeOp = .STORE,
		clearValue = {color = device.clear_color},
	}
	rendering := vk.RenderingInfo {
		sType = .RENDERING_INFO,
		renderArea = {extent = device.swapchain.extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &color,
	}
	vk.CmdBeginRendering(cmd, &rendering)

	extent := device.swapchain.extent
	viewport := vk.Viewport {
		x        = 0,
		y        = f32(extent.height),
		width    = f32(extent.width),
		height   = -f32(extent.height), // Y flip: keeps Metal-style clip space (y up)
		minDepth = 0,
		maxDepth = 1,
	}
	scissor := vk.Rect2D {
		extent = extent,
	}
	vk.CmdSetViewport(cmd, 0, 1, &viewport)
	vk.CmdSetScissor(cmd, 0, 1, &scissor)
	vk.CmdBindDescriptorSets(
		cmd,
		.GRAPHICS,
		device.pipeline_layout,
		0,
		1,
		&device.bind_table.set,
		0,
		nil,
	)

	return true
}

device_present :: proc(device: ^Device) {
	frame := &device.frames[device.frame_slot_index]
	cmd := frame.command_buffer
	index := device.swapchain.image_index

	vk.CmdEndRendering(cmd)
	cmd_image_barrier(
		cmd,
		device.swapchain.images[index],
		.COLOR_ATTACHMENT_OPTIMAL,
		.PRESENT_SRC_KHR,
		{.COLOR_ATTACHMENT_OUTPUT},
		{.COLOR_ATTACHMENT_WRITE},
		{},
		{},
	)
	vk.EndCommandBuffer(cmd)

	command_infos: [2]vk.CommandBufferSubmitInfo
	command_count := 0
	if uploads_record(device, frame) {
		command_infos[command_count] = {
			sType         = .COMMAND_BUFFER_SUBMIT_INFO,
			commandBuffer = frame.upload_buffer,
		}
		command_count += 1
	}
	command_infos[command_count] = {
		sType         = .COMMAND_BUFFER_SUBMIT_INFO,
		commandBuffer = cmd,
	}
	command_count += 1

	wait := vk.SemaphoreSubmitInfo {
		sType     = .SEMAPHORE_SUBMIT_INFO,
		semaphore = frame.image_available,
		stageMask = {.COLOR_ATTACHMENT_OUTPUT},
	}
	signal := vk.SemaphoreSubmitInfo {
		sType     = .SEMAPHORE_SUBMIT_INFO,
		semaphore = device.swapchain.render_finished[index],
		stageMask = {.COLOR_ATTACHMENT_OUTPUT},
	}
	submit := vk.SubmitInfo2 {
		sType                    = .SUBMIT_INFO_2,
		waitSemaphoreInfoCount   = 1,
		pWaitSemaphoreInfos      = &wait,
		commandBufferInfoCount   = u32(command_count),
		pCommandBufferInfos      = &command_infos[0],
		signalSemaphoreInfoCount = 1,
		pSignalSemaphoreInfos    = &signal,
	}
	result := vk.QueueSubmit2(device.queue, 1, &submit, frame.fence)
	if !device_vulkan_ok(result, "vkQueueSubmit") {
		return
	}

	present := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &device.swapchain.render_finished[index],
		swapchainCount     = 1,
		pSwapchains        = &device.swapchain.handle,
		pImageIndices      = &index,
	}

	result = vk.QueuePresentKHR(device.queue, &present)
	if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR {
		device.swapchain_dirty = true
	}
}

@(private = "file")
device_debug_callback :: proc "system" (
	severity: vk.DebugUtilsMessageSeverityFlagsEXT,
	types: vk.DebugUtilsMessageTypeFlagsEXT,
	data: ^vk.DebugUtilsMessengerCallbackDataEXT,
	user_data: rawptr,
) -> b32 {
	context = (^runtime.Context)(user_data)^
	if .ERROR in severity {
		log.errorf("vulkan: %s", data.pMessage)
	} else {
		log.warnf("vulkan: %s", data.pMessage)
	}

	return false
}

@(private)
device_vulkan_ok :: proc(result: vk.Result, what: string) -> bool {
	if result != .SUCCESS {
		log.errorf("gpu: %s failed with %v", what, result)
		return false
	}
	return true
}

device_destroy :: proc(device: ^Device) {
	if device.handle != nil {
		vk.DeviceWaitIdle(device.handle)

		if device.bind_table != nil {
			bind_table_destroy(device.bind_table)
		}
		buffer_destroy(&device.vertex_ring)
		upload_queue_destroy(&device.uploads)

		for pipeline in device.pipelines {
			vk.DestroyPipeline(device.handle, pipeline, nil)
		}
		vk.DestroyPipelineLayout(device.handle, device.pipeline_layout, nil)
		vk.DestroyDescriptorSetLayout(device.handle, device.vertex_set_layout, nil)

		for &frame in device.frames {
			buffer_slot_destroy(device, &frame.staging)
			vk.DestroyFence(device.handle, frame.fence, nil)
			vk.DestroySemaphore(device.handle, frame.image_available, nil)
		}
		vk.DestroyCommandPool(device.handle, device.command_pool, nil) // frees command buffers

		swapchain_release(device, &device.swapchain)
		vk.DestroyDevice(device.handle, nil)
	}

	if device.instance != nil {
		vk.DestroySurfaceKHR(device.instance, device.surface, nil)
		when VALIDATION {
			if device.debug_messenger != 0 {
				vk.DestroyDebugUtilsMessengerEXT(device.instance, device.debug_messenger, nil)
			}
		}
		vk.DestroyInstance(device.instance, nil)
	}

	free(device)
}
