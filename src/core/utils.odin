package ome

import "core:fmt"
import "core:os"
import "core:strings"

get_texture_paths_in_derectory :: proc(path: string) -> []string {
	dir, open_err := os.open(path)
	assert(open_err == os.ERROR_NONE, fmt.tprintln("Couldn't open directory: ", path))
	defer os.close(dir)

	file_infos, read_err := os.read_dir(dir, 0, context.allocator)
	assert(read_err == os.ERROR_NONE, fmt.tprintln("Couldn't read directory: ", path))

	defer os.file_info_slice_delete(file_infos, context.allocator)

	names: [dynamic]string = {}
	for file_info in file_infos {
		if file_info.type != os.File_Type.Regular {
			continue
		}

		append(&names, strings.clone(file_info.fullpath))
	}

	return names[:]
}
