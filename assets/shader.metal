using namespace metal;

struct ColoredVertex {
	float4 position [[position]];
	float4 color;
	float2 uv;
	uint   mode;
	uint   tex_id;
};

vertex ColoredVertex vertex_main(
	constant float4 *position [[buffer(0)]],
	constant float4 *color    [[buffer(1)]],
	constant float2 *uv       [[buffer(2)]],
	constant uint  *mode      [[buffer(3)]],
	constant uint  *tex_id    [[buffer(4)]],
	uint vid                  [[vertex_id]])
{
	ColoredVertex vert;
	vert.position = position[vid];
	vert.color    = color[vid];
	vert.uv       = uv[vid].xy;
	vert.mode     = mode[vid];
	vert.tex_id   = tex_id[vid];
	return vert;
}

constant constexpr int MAX_SPRITES = 256;

struct SpriteTable {
    array<texture2d<float>, MAX_SPRITES> textures [[id(0)]];
    sampler s [[id(MAX_SPRITES)]];
};

fragment float4 fragment_main(
	ColoredVertex        vert      [[stage_in]],
	texture2d<float>     font_tex  [[texture(0)]],
	sampler              font_samp [[sampler(0)]],
    device const SpriteTable& sprites [[buffer(0)]])
{
	if (vert.mode == 1u) {
		float alpha = font_tex.sample(font_samp, vert.uv).r;
		return float4(vert.color.rgb, vert.color.a * alpha);
	}
	if (vert.mode == 2u) {
	    return sprites.textures[vert.tex_id].sample(sprites.s, vert.uv) * vert.color;
	}
	return vert.color;
}
