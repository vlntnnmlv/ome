using namespace metal;

struct VertexIn {
	packed_float4 position;
	packed_float2 uv;
	packed_float4 color;
	uint   mode;
	uint   tex_id;
};

struct VertexOut {
	float4 position [[position]];
	float2 uv;
	float4 color;
	uint   mode;
	uint   tex_id;
};

vertex VertexOut vertex_main(
	constant VertexIn *vertices [[buffer(0)]],
	uint vid                  [[vertex_id]])
{
    VertexIn in = vertices[vid];
    VertexOut out;
    out.position = float4(in.position);
    out.uv = float2(in.uv);
    out.color = float4(in.color);
    out.mode = in.mode;
    out.tex_id = in.tex_id;
	return out;
}

constant constexpr int MAX_SPRITES = 256;

struct SpriteTable {
    array<texture2d<float>, MAX_SPRITES> textures [[id(0)]];
    sampler s [[id(MAX_SPRITES)]];
};

fragment float4 fragment_main(
	VertexOut        vert      [[stage_in]],
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
