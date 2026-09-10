package omecore

import "core:math"

Color :: distinct [4]u8

TRANSPARENT :: Color{0, 0, 0, 0}
BLACK :: Color{0, 0, 0, 255}
WHITE :: Color{255, 255, 255, 255}

@(private)
srgb_to_linear_lut: [256]f32

@(private, init)
build_srgb_lut :: proc "contextless" () {
	for i in 0 ..< 256 {
		c := f32(i) / 255.0
		srgb_to_linear_lut[i] = c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4)
	}
}

color_to_linear32 :: proc(c: Color) -> [4]f32 {
	return {
		srgb_to_linear_lut[(c.r)],
		srgb_to_linear_lut[(c.g)],
		srgb_to_linear_lut[(c.b)],
		f32(c.a) / 255.0,
	}
}

color_to_linear64 :: proc(c: Color) -> [4]f64 {
	l := color_to_linear32(c)
	return {f64(l.r), f64(l.g), f64(l.b), f64(l.a)}
}
