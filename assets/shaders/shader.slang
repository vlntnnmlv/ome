// 2D sprite/font/solid shader. Compiled to SPIR-V by gpu/shader.odin.

static const int MAX_TEXTURES = 256; // MUST match gpu.MAX_TEXTURES

// MUST match Odin `Vertex2D` (src/gpu/pipeline.odin) byte-for-byte:
//
//   offset  0  position : [4]f32
//   offset 16  uv       : [2]f32
//   offset 24  color    : [4]f32
//   offset 40  mode     : u32
//   offset 44  tex_id   : u32
//   size 48, align 4
//
// All-scalar members on purpose: a float4 member would get 16-byte alignment
// under std430 and push `color` to offset 32 / stride to 64.
struct VertexIn {
  float px, py, pz, pw;
  float u, v;
  float cr, cg, cb, ca;
  uint mode;
  uint tex_id;
};

struct VertexOut {
  float4 position : SV_Position;
  float2 uv : TEXCOORD0;
  float4 color : COLOR0;
  nointerpolation uint mode : MODE;
  nointerpolation uint tex_id : TEXID;
};

// Column-major, matches Odin `matrix[4,4]f32` (compiled with
// -matrix-layout-column-major).
struct CameraUniform {
  float4x4 view_proj;
};
[[vk::push_constant]]
ConstantBuffer<CameraUniform> camera;

// set 0: bindless, bound once per frame
[[vk::binding(0, 0)]]
Texture2D<float4> textures[MAX_TEXTURES];
[[vk::binding(1, 0)]]
SamplerState sprite_sampler;

// set 1: push descriptor, the frame slot's vertex ring buffer
[[vk::binding(0, 1)]]
StructuredBuffer<VertexIn> vertices;

[shader("vertex")]
VertexOut vertex_main(uint vid: SV_VulkanVertexID) {
  VertexIn vin = vertices[vid];
  VertexOut o;
  o.position = mul(camera.view_proj, float4(vin.px, vin.py, vin.pz, vin.pw));
  o.uv = float2(vin.u, vin.v);
  o.color = float4(vin.cr, vin.cg, vin.cb, vin.ca);
  o.mode = vin.mode;
  o.tex_id = vin.tex_id;
  return o;
}

[shader("fragment")]
float4 fragment_main(VertexOut vert) : SV_Target {
  if (vert.mode == 1u) {
    return textures[NonUniformResourceIndex(vert.tex_id)]
               .Sample(sprite_sampler, vert.uv)
               .x *
           vert.color;
  }
  if (vert.mode == 2u) {
    return textures[NonUniformResourceIndex(vert.tex_id)].Sample(sprite_sampler,
                                                                 vert.uv) *
           vert.color;
  }
  return vert.color;
}
