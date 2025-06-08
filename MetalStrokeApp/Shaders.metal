#include <metal_stdlib>
using namespace metal;

#define PI acos(-1.)
#define PIH acos(0.)

struct StrokeVertex {
    packed_float2 pos;
    float4 color;
    float radius;
    float end;
};

struct VtxOut {
    float4 pos [[position]];
    float4 color;
};

float2 rotate(float2 pos, float angle) {
    return float2(pos.x * cos(angle) - pos.y * sin(angle),
                  pos.x * sin(angle) + pos.y * cos(angle));
}

vertex VtxOut vtx_main(
    const device StrokeVertex* vertices[[buffer(0)]],
    const device float2* rectPos[[buffer(1)]],
    constant uint& drawMode [[buffer(2)]],
    uint vid [[vertex_id]],
    uint iid [[instance_id]]
) {
    VtxOut out;
    
    StrokeVertex v0 = vertices[iid];
    StrokeVertex v1 = vertices[iid + 1];
    
    float2 dp = v1.pos - v0.pos;
    float sy = length(dp);
    float angle = atan2(dp.y, dp.x) - PIH;
    
    // coordinate in rect
    float2 localpos = rectPos[vid];
    
    StrokeVertex v2;
    uint rotend = 0;
    if (localpos.y < 0.5 && v0.end == 0) {
        v2 = vertices[iid - 1];
        dp = v0.pos - v2.pos;
        rotend = 1;
    } else if (localpos.y > 0.5 && v1.end == 0){
        v2 = vertices[iid + 2];
        dp = v2.pos - v1.pos;
        rotend = 1;
    }
    
    float angle2 = atan2(dp.y, dp.x) - PIH;
    angle2 = (angle + angle2) * 0.5;
    if (abs(angle - angle2) > PIH) {
        angle2 += -sign(angle2) * PI;
    }
    
    // pos(x only)
    float2 pos = float2(mix(v0.radius, v1.radius, localpos.y) * localpos.x, 0);
    
    // rotate ends first
    pos = rotate(pos, rotend ? angle2 : angle);
    
    // add y component
    pos += rotate(float2(0, localpos.y * sy), angle);
    
    // translate by start pos
    pos += v0.pos;
    
    out.pos = float4(pos, 0, 1);
    
    if (drawMode == 0) {
        // fill
        out.color = ((vid + 1) % 4) < 2 ? float4(1,0,0,0) : float4(0,0,1,1);
        // out.color = mix(v0.color, v1.color, localpos.y);
    } else if (drawMode == 1) {
        // wireframe
        out.color = float4(1,1,1,1);
        out.pos.z += 0.1;
    }
    
    return out;
}

fragment float4 frag_main(VtxOut in [[stage_in]]) {
//    return float4(1.0, 0.2, 0.8, 1.0);
    return in.color;
}
