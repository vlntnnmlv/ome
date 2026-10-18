package omegpu

import "core:mem"

import vk "vendor:vulkan"

import "ome:handle_map"

@(private)
STAGING_ALIGNMENT :: 16

@(private)
STAGING_INITIAL_SIZE :: 4 * 1024 * 1024

@(private)
PendingUpload :: struct {
	handle: TextureHandle,
	offset: [2]i32,
	extent: [2]u32,
	bytes:  []u8, // owned, tightly packed rows, freed after recording
}

@(private)
UploadQueue :: struct {
	pending: [dynamic]PendingUpload,
}

@(private)
upload_queue_push :: proc(
	queue: ^UploadQueue,
	handle: TextureHandle,
	offset: [2]i32,
	extent: [2]u32,
	bytes: []u8,
) {
	append(&queue.pending, PendingUpload{handle, offset, extent, bytes})
}

@(private)
upload_queue_destroy :: proc(queue: ^UploadQueue) {
	for upload in queue.pending {
		delete(upload.bytes)
	}
	delete(queue.pending)
}

// Records every pending upload into frame.upload_buffer.
// Returns false when there was nothing to record.
@(private)
uploads_record :: proc(device: ^Device, frame: ^FrameSlot) -> bool {
	queue := &device.uploads
	if len(queue.pending) == 0 {
		return false
	}

	total := 0
	for upload in queue.pending {
		total += mem.align_forward_int(len(upload.bytes), STAGING_ALIGNMENT)
	}
	if !staging_reserve(device, &frame.staging, total) {
		return false // the queue stays, so it's retried next frame
	}

	cmd := frame.upload_buffer
	vk.ResetCommandBuffer(cmd, {})
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	vk.BeginCommandBuffer(cmd, &begin_info)

	staging := ([^]u8)(frame.staging.mapped)
	cursor := 0

	for upload in queue.pending {
		defer delete(upload.bytes)

		texture := handle_map.get(device.bind_table.textures, upload.handle)
		if texture == nil {
			continue // released before its upload was flushed
		}

		mem.copy(&staging[cursor], raw_data(upload.bytes), len(upload.bytes))

		old_layout: vk.ImageLayout =
			.SHADER_READ_ONLY_OPTIMAL if texture.layout_initialized else .UNDEFINED
		cmd_image_barrier(
			cmd,
			texture.image,
			old_layout,
			.TRANSFER_DST_OPTIMAL,
			src_stage = {.FRAGMENT_SHADER},
			src_access = {},
			dst_stage = {.COPY},
			dst_access = {.TRANSFER_WRITE},
		)

		region := vk.BufferImageCopy {
			bufferOffset = vk.DeviceSize(cursor),
			imageSubresource = {aspectMask = {.COLOR}, layerCount = 1},
			imageOffset = {upload.offset.x, upload.offset.y, 0},
			imageExtent = {upload.extent.x, upload.extent.y, 1},
		}
		vk.CmdCopyBufferToImage(
			cmd,
			frame.staging.handle,
			texture.image,
			.TRANSFER_DST_OPTIMAL,
			1,
			&region,
		)

		cmd_image_barrier(
			cmd,
			texture.image,
			.TRANSFER_DST_OPTIMAL,
			.SHADER_READ_ONLY_OPTIMAL,
			src_stage = {.COPY},
			src_access = {.TRANSFER_WRITE},
			dst_stage = {.FRAGMENT_SHADER},
			dst_access = {.SHADER_SAMPLED_READ},
		)

		texture.layout_initialized = true
		cursor += mem.align_forward_int(len(upload.bytes), STAGING_ALIGNMENT)
	}

	clear(&queue.pending)
	vk.EndCommandBuffer(cmd)
	return true
}

// Safe to grow: called from device_present, after device_begin waited on this slot's fence.
@(private = "file")
staging_reserve :: proc(device: ^Device, staging: ^BufferSlot, size: int) -> bool {
	if staging.size >= size {
		return true
	}

	new_size := max(staging.size, STAGING_INITIAL_SIZE)
	for new_size < size {
		new_size *= 2
	}

	buffer_slot_destroy(device, staging)
	slot, ok := buffer_slot_create(device, new_size, {.TRANSFER_SRC})
	staging^ = slot
	return ok
}
