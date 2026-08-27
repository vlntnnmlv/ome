// 2D sprite/font/solid shader — authored in Slang, cross-compiled to MSL.
// slangc sprite.slang -target metal -o sprite.metal

static const int MAX_SPRITES = 256;

// MUST match Odin `Vertex2D` (src/core/graphics.odin) byte-for-byte:
//
//   offset  0  position : [4]f32
//   offset 16  uv       : [2]f32
//   offset 24  color    : [4]f32
//   offset 40  mode     : u32
//   offset 44  tex_id   : u32
//   size 48, align 4
//
// Fields are declared as loose scalars ON PURPOSE. Slang has no `packed_float4`,
// so a `float4 position` member would force 16-byte alignment in the emitted MSL
// and push `color` to offset 32 / the stride to 64 — silently misreading every
// vertex after the first. All-scalar members keep align 4 and stride 48.
struct VertexIn {
  float px, py, pz, pw; // position
  float u, v;           // uv
  float cr, cg, cb, ca; // color
  uint mode;
  uint tex_id;
};

struct VertexOut {
  float4 position : SV_Position;
  float2 uv : TEXCOORD0;
  float4 color : COLOR0;
  nointerpolation uint mode : MODE; // ints must not interpolate -> [[flat]]
  nointerpolation uint tex_id : TEXID;
};

// argument buffer: 256 textures at ids 0..255, sampler at id 256.
// Declared first so it takes Metal buffer(0) in BOTH stages, which is where the
// Odin side binds `texture_manager.arguments`.
struct SpriteTable {
  Texture2D<float4> textures[MAX_SPRITES];
  SamplerState s;
};
ParameterBlock<SpriteTable> sprites : register(b0);

// Vertex stream, pulled by vertex_id. Lands on Metal buffer(1) in BOTH stages —
// Slang hands every global to every entry point, so the fragment stage declares
// it too even though it never reads it.
StructuredBuffer<VertexIn> vertices : register(t1);

Texture2D<float4> font_tex;  // texture(0)
SamplerState font_samp;      // sampler(0)

[shader("vertex")]
VertexOut vertex_main(uint vid: SV_VertexID) {
  VertexIn vin = vertices[vid];
  VertexOut o;
  o.position = float4(vin.px, vin.py, vin.pz, vin.pw);
  o.uv = float2(vin.u, vin.v);
  o.color = float4(vin.cr, vin.cg, vin.cb, vin.ca);
  o.mode = vin.mode;
  o.tex_id = vin.tex_id;
  return o;
}

[shader("fragment")]
float4 fragment_main(VertexOut vert) : SV_Target {
  if (vert.mode == 1u) {
    float alpha = font_tex.Sample(font_samp, vert.uv).r;
    return float4(vert.color.rgb, vert.color.a * alpha);
  }
  if (vert.mode == 2u) {
    return sprites.textures[vert.tex_id].Sample(sprites.s, vert.uv) *
           vert.color;
  }
  return vert.color;
}
