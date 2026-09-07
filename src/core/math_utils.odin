package ome

interpolate :: proc(a: [2]f32, b: [2]f32, phase: f32) -> [2]f32 {
	return a + (b - a) * phase
}
