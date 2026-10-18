package omegpu

import vk "vendor:vulkan"

@(private)
TopologyClass :: enum {
	Line,
	Triangle,
}

Mode :: enum u32 {
	Primitive = 0,
	Text      = 1,
	Texture   = 2,
}

Position :: distinct [4]f32
UV :: distinct [2]f32
TextureID :: distinct u32

Vertex2D :: struct {
	position:   Position,
	uv:         UV,
	color:      [4]f32,
	mode:       Mode,
	texture_id: TextureID,
}

@(rodata, private = "file")
TOPOLOGY_CLASS_BASE := [TopologyClass]vk.PrimitiveTopology {
	.Line     = .LINE_LIST,
	.Triangle = .TRIANGLE_LIST,
}

@(private)
pipelines_create :: proc(device: ^Device) -> bool {
	module, module_ok := shader_load_module(device, "assets/shaders/shader.slang")
	if !module_ok {
		return false
	}
	defer vk.DestroyShaderModule(device.handle, module, nil)

	vertex_binding := vk.DescriptorSetLayoutBinding {
		binding         = 0,
		descriptorType  = .STORAGE_BUFFER,
		descriptorCount = 1,
		stageFlags      = {.VERTEX},
	}
	vertex_set_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		flags        = {.PUSH_DESCRIPTOR},
		bindingCount = 1,
		pBindings    = &vertex_binding,
	}
	result := vk.CreateDescriptorSetLayout(
		device.handle,
		&vertex_set_info,
		nil,
		&device.vertex_set_layout,
	)
	if !device_vulkan_ok(result, "vkCreateDescriptorSetLayout") {
		return false
	}

	set_layouts := [2]vk.DescriptorSetLayout{device.bind_table.layout, device.vertex_set_layout}
	push_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset     = 0,
		size       = size_of(matrix[4, 4]f32),
	}
	layout_info := vk.PipelineLayoutCreateInfo {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount         = len(set_layouts),
		pSetLayouts            = &set_layouts[0],
		pushConstantRangeCount = 1,
		pPushConstantRanges    = &push_range,
	}
	result = vk.CreatePipelineLayout(device.handle, &layout_info, nil, &device.pipeline_layout)
	if !device_vulkan_ok(result, "vkCreatePipelineLayout") {
		return false
	}

	for class in TopologyClass {
		if !pipeline_create(device, module, class) {
			return false
		}
	}
	return true
}

@(private = "file")
pipeline_create :: proc(device: ^Device, module: vk.ShaderModule, class: TopologyClass) -> bool {
	stages := [2]vk.PipelineShaderStageCreateInfo {
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.VERTEX},
			module = module,
			pName = "vertex_main",
		},
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.FRAGMENT},
			module = module,
			pName = "fragment_main",
		},
	}
	vertex_input := vk.PipelineVertexInputStateCreateInfo {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO, // vertex pulling: no attributes
	}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = TOPOLOGY_CLASS_BASE[class],
	}
	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount  = 1,
	}
	raster := vk.PipelineRasterizationStateCreateInfo {
		sType       = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		polygonMode = .FILL,
		frontFace   = .COUNTER_CLOCKWISE, // verify with CullMode.Back, see bring-up step 4
		lineWidth   = 1,
	}
	multisample := vk.PipelineMultisampleStateCreateInfo {
		sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		rasterizationSamples = {._1},
	}
	blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable         = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp        = .ADD,
		srcAlphaBlendFactor = .SRC_ALPHA,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp        = .ADD,
		colorWriteMask      = {.R, .G, .B, .A},
	}
	blend := vk.PipelineColorBlendStateCreateInfo {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		attachmentCount = 1,
		pAttachments    = &blend_attachment,
	}
	dynamic_states := [4]vk.DynamicState{.VIEWPORT, .SCISSOR, .CULL_MODE, .PRIMITIVE_TOPOLOGY}
	dynamic_state := vk.PipelineDynamicStateCreateInfo {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = len(dynamic_states),
		pDynamicStates    = &dynamic_states[0],
	}
	color_format := SWAPCHAIN_FORMAT
	rendering_info := vk.PipelineRenderingCreateInfo {
		sType                   = .PIPELINE_RENDERING_CREATE_INFO,
		colorAttachmentCount    = 1,
		pColorAttachmentFormats = &color_format,
	}
	pipeline_info := vk.GraphicsPipelineCreateInfo {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = &rendering_info,
		stageCount          = len(stages),
		pStages             = &stages[0],
		pVertexInputState   = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState      = &viewport_state,
		pRasterizationState = &raster,
		pMultisampleState   = &multisample,
		pColorBlendState    = &blend,
		pDynamicState       = &dynamic_state,
		layout              = device.pipeline_layout,
	}
	result := vk.CreateGraphicsPipelines(
		device.handle,
		0,
		1,
		&pipeline_info,
		nil,
		&device.pipelines[class],
	)
	return device_vulkan_ok(result, "vkCreateGraphicsPipelines")
}
