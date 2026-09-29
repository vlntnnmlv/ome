package omegpu

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
