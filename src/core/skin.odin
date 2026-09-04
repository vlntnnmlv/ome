package ome

Style :: struct {
	texture_handle: TextureHandle,
	nine_slice:     RectOffset,
	uvs:            []Uv,
}

Skin :: struct {
	styles: [dynamic]Style,
}

style_create :: proc() -> Skin {
	return Skin{styles = make([dynamic]Style)}
}

style_add :: proc(sprite: SpriteData, nine_slice: RectOffset) {

}
