	using namespace metal;

	struct ColoredVertex {
		float4 position [[position]];
		float4 color;
		float2 uv;
		uint   mode;
	};

	vertex ColoredVertex vertex_main(
		constant float4 *position [[buffer(0)]],
		constant float4 *color    [[buffer(1)]],
		constant float2 *uv       [[buffer(2)]],
		constant int  *mode       [[buffer(3)]],
		uint vid                  [[vertex_id]])
	{
		ColoredVertex vert;
		vert.position = position[vid];
		vert.color    = color[vid];
		vert.uv       = uv[vid].xy;
		vert.mode     = mode[vid];
		return vert;
	}

	fragment float4 fragment_main(
		ColoredVertex        vert      [[stage_in]],
		texture2d<float>     font_tex  [[texture(0)]],
		sampler              font_samp [[sampler(0)]])
	{
		if (vert.mode == 1u) {
			float alpha = font_tex.sample(font_samp, vert.uv).r;
			return float4(vert.color.rgb, vert.color.a * alpha);
		}
		return vert.color;
	}
