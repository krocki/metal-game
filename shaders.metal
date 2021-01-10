#include <metal_stdlib>
using namespace metal;

#include "defs.h"

struct VertexOut {
  float4 color;
  float4 pos [[position]];
  float2 tex;
};

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
  // Get the data for the current vertex.
  Vertex in = vertexArray[vid];
  VertexOut out;

  // Pass the vertex color directly to the rasterizer
  out.color = in.color;
  // Pass the already normalized screen-space coordinates to the rasterizer
  out.pos = float4(in.pos.x, in.pos.y, 0, 1);
  out.tex = (in.tex + float2(1))/ float2(2);
  return out;
}

fragment float4 fragmentShader(VertexOut x [[stage_in]], texture2d<uint> tex2D [[texture(0)]])
{
  constexpr sampler smplr(coord::normalized,
                          address::clamp_to_zero,
                          filter::nearest);
  uint v = tex2D.sample(smplr, x.tex).r;
  return float4(v);
}

kernel void step(texture2d<uint, access::read>  current [[texture(0)]],
                 texture2d<uint, access::write> next [[texture(1)]],
                 uint2 index [[thread_position_in_grid]]) {

  short live_neighbours = 0;

  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      if (i != 0 || j != 0) {
        uint2 neighbour = index + uint2(i, j);
        if (1 == current.read(neighbour).r) {
          live_neighbours++;
        }
      }
    }
  }

  bool is_alive = 1 == current.read(index).r;

  if (is_alive) {
    if (live_neighbours < 2) {
      next.write(0, index);  // die from under-population
    } else if (live_neighbours > 3) {
      next.write(0, index);  // die from over-population
    } else {
      next.write(1, index);  // stay alive
    }
  } else {  // !is_alive
    if (live_neighbours == 3) {
      next.write(1, index);  // newborn cell
    } else {
      next.write(0, index);  // stay dead
    }
  }
}
