package omecore

import "core:log"
import "core:os"
import "core:strings"

directory_list_files :: proc(path: string) -> ([]string, bool) {
	dir, open_err := os.open(path)
	if open_err != os.ERROR_NONE {
		log.errorf("core/fs: failed to open directory '%s' with error %v", path, open_err)
		return nil, false
	}
	defer os.close(dir)

	file_infos, read_err := os.read_dir(dir, 0, context.allocator)
	if read_err != os.ERROR_NONE {
		log.errorf("core/fs: failed to read directory '%s' with error %v", path, read_err)
		return nil, false
	}

	defer os.file_info_slice_delete(file_infos, context.allocator)

	names: [dynamic]string = {}
	for file_info in file_infos {
		if file_info.type != os.File_Type.Regular {
			continue
		}

		append(&names, strings.clone(file_info.fullpath))
	}

	return names[:], true
}
