package omegpu

import "core:log"
import "core:os"

import vk "vendor:vulkan"

@(private)
SHADER_CACHE_PATH :: "cache/shader.spv"

@(private)
shader_load_module :: proc(device: ^Device, path: string) -> (vk.ShaderModule, bool) {
	if !shader_compile_slang(path, SHADER_CACHE_PATH) {
		return 0, false
	}

	spirv, read_err := os.read_entire_file(SHADER_CACHE_PATH, context.temp_allocator)
	if read_err != nil {
		log.errorf(
			"gpu/shader: couldn't read '%s': %v",
			SHADER_CACHE_PATH,
			os.error_string(read_err),
		)
		return 0, false
	}

	module_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(spirv),
		pCode    = cast(^u32)raw_data(spirv),
	}
	module: vk.ShaderModule
	result := vk.CreateShaderModule(device.handle, &module_info, nil, &module)
	if !device_vulkan_ok(result, "vkCreateShaderModule") {
		return 0, false
	}
	return module, true
}

@(private = "file")
shader_compile_slang :: proc(path: string, out_path: string) -> bool {
	state, _, stderr, err := os.process_exec(
		os.Process_Desc {
			command = {
				"slangc",
				path,
				"-target",
				"spirv",
				"-entry",
				"vertex_main",
				"-stage",
				"vertex",
				"-entry",
				"fragment_main",
				"-stage",
				"fragment",
				"-fvk-use-entrypoint-name",
				"-matrix-layout-column-major",
				"-o",
				out_path,
			},
		},
		context.temp_allocator,
	)
	if err != nil {
		log.errorf("gpu/shader: couldn't run slangc: %v", os.error_string(err))
		return false
	}
	if !state.success || state.exit_code != 0 {
		log.errorf("gpu/shader: slangc failed (exit %d):\n%s", state.exit_code, string(stderr))
		return false
	}
	if len(stderr) > 0 {
		log.warnf("gpu/shader: slangc: %s", string(stderr))
	}
	return true
}
