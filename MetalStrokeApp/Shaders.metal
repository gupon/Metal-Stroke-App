#include <metal_stdlib>
using namespace metal;

#define PI acos(-1.)
#define PIH acos(0.)

struct StrokeVertex {
    packed_float2 pos;
    float4 color;
    float radius;
    float end;
    uchar capType;
    uchar joinType;
    uchar reserved0;
    uchar reserved1;
};

struct VtxOut {
    float4 pos [[position]];
    float4 color;
    float ptsize [[point_size]] = 6.0;
};

float2x2 rotateSkewMat(float angle, bool skew=false) {
    float s = sin(angle);
    float c = cos(angle);
    float sx = skew ? 1.0 / abs(c) : 1.0;
    return float2x2(c * sx, -s, s * sx, c);
}

float wrap_angle_PIH(float angle) {
    if (abs(angle) > PIH) {
        angle -= sign(angle) * PI;
    }
    return angle;
}

float calcMiterEndAngle (float angleA, float2 dirB) {
    float angleB = atan2(dirB.y, dirB.x);
    float mid_angle = (angleA + angleB) * 0.5;
    return wrap_angle_PIH(mid_angle - angleA);
}


/*
 for debug wireframes / points
 */
vertex VtxOut vtx_debug(
    const device StrokeVertex* vertices[[buffer(0)]],
    uint vid [[vertex_id]],
    constant uint& drawStep [[buffer(3)]]
) {
    VtxOut out;
    
    StrokeVertex vtx = vertices[vid];
    out.pos = float4(vtx.pos, 0.2, 1);
    
    if (drawStep == 0) {
        out.color = float4(1,1,1,1);
        out.ptsize = 16.0;
    } else if (drawStep == 1) {
        out.color = vtx.color;
        out.ptsize = 14.0;
        out.pos.z += 0.2;
    }
    
    return out;
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
    
    // skip drawing if end
    if (v0.end == 1) {
        out.color = float4(0);
        out.pos = float4(v0.pos, 0, 1);
        return out;
    }
    
    // coordinate in rect
    float2 localpos = rectPos[vid];

    float2 dp = v1.pos - v0.pos;
    float angleA = atan2(dp.y, dp.x);
    
    // position: set x first
    float2 pos = float2(mix(v0.radius, v1.radius, localpos.y) * localpos.x * 2, 0);
    
    bool isMidStart = localpos.y < 0.5 && v0.end == 0;
    bool isMidEnd = localpos.y > 0.5 && v1.end == 0;
    
    if (0 && (isMidStart || isMidEnd)) {
        // rotate end for midpoints
        float ends_angle = 0;
        float2 dirB = isMidStart ? (v0.pos - vertices[iid-1].pos) : (vertices[iid+2].pos - v1.pos);
        ends_angle = calcMiterEndAngle(angleA, dirB);
        pos *= rotateSkewMat(ends_angle, true);
    }
    
    pos += float2(0, localpos.y) * distance(v0.pos, v1.pos);      // add y
    pos *= rotateSkewMat(angleA - PIH);     // rotate
    pos += v0.pos;                          // add base pos
    
    // form out
    out.pos = float4(pos, 0, 1);
    
    if (drawMode == 0) {
        // fill
        out.color = ((vid + 1) % 4) < 2 ? float4(1,0,0,0) : float4(0,0,1,1);
        out.color = mix(v0.color, v1.color, localpos.y);
    } else if (drawMode == 1) {
        // wireframe
        out.color = float4(1,1,1,0.5);
        out.pos.z += 0.1;
    }
    
    return out;
}

fragment float4 frag_main(VtxOut in [[stage_in]]) {
    return in.color;
}
