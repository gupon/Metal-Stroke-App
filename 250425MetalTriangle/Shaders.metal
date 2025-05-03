#include <metal_stdlib>
using namespace metal;

struct StrokeVertex {
    packed_float2 pos;
    float4 color;
    float radius;
    float _pad;
};

struct PointData {
    float4 pos [[position]];
    float4 color;
    uint id;
};

vertex PointData vtx_main(const device StrokeVertex* vertices[[buffer(0)]],
                       uint vid [[vertex_id]]) {
    StrokeVertex vtx = vertices[vid];
    PointData data;
    data.pos = float4(vtx.pos, 0, 1);
    data.color = vtx.color;
    data.id = vid;
    return data;
}

fragment float4 frag_main(PointData in [[stage_in]]) {
//    return float4(1.0, 0.2, 0.8, 1.0);
    return in.color;
}
