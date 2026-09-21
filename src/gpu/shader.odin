package omegpu

import "core:log"
import "core:os"

@(private)
shader_compile_slang :: proc(
	path: string,
	allocator := context.temp_allocator,
) -> (
	source: string,
	ok: bool,
) {
	state, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = {"slangc", path, "-target", "metal"}},
		allocator,
	)
	if err != nil {
		log.errorf("Couldn't run slangc: %v", os.error_string(err))
		return "", false
	}
	if !state.success || state.exit_code != 0 {
		log.errorf("slangc failed (exit %d):\n%s", state.exit_code, string(stderr))
		return "", false
	}
	if len(stderr) > 0 {
		log.warnf("slangc: %s", string(stderr))
	}
	return string(stdout), true
}
