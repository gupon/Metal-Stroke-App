#include <metal_stdlib>
using namespace metal;

#define PI acos(-1.)
#define PIH acos(0.)

// match with Renderer > BufferIndex
#define BUFID_VERTEX 0
#define BUFID_RECT 1
#define BUFID_ROUND 2
#define BUFID_ROUNDRES 3
#define BUFID_JOINS 4
#define BUFID_CAPS 5
#define BUFID_DRAWMODE 9
#define BUFID_POINTSTEP 10
#define BUFID_DEBUG 20

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

float wrap_angle(float angle, float segment=PI) {
    if (abs(angle) > segment)
        angle -= sign(angle) * segment * 2.0;
    return angle;
}

float vectorAngle (float2 a, float2 b) {
    float2 dp = b - a;
    return atan2(dp.y, dp.x);
}

float miterAngle (float a, float b) {
    return wrap_angle((a + b) * 0.5 - a, PIH);
}

float fit (float value, float from_min, float from_max, float to_min, float to_max) {
    return to_min + (value - from_min) / (from_max - from_min) * (to_max - to_min);
}

/*
 Interpolate color inside Round Join
 
 slightly shift color toward prev/next vertex color
 */
float4 calcRoundJoinColor (StrokeVertex v0, StrokeVertex vPrev, StrokeVertex vNext, float miterAngle, float ratio) {
    StrokeVertex vB = ratio < 0.5 ? vPrev : vNext;
    
    float dist = distance(v0.pos, vB.pos);
    float end_weight = abs(tan(miterAngle)) * v0.radius / dist;
    
    // normalized ratio from inside(center) to ouside
    float weight = ratio < 0.5 ? fit(ratio, 0, 0.5, 1, 0) : fit(ratio, 0.5, 1, 0, 1);
    weight *= end_weight;
    
    return mix(v0.color, vB.color, weight);
}



vertex VtxOut vert_main (
    const device StrokeVertex* vertices[[buffer(BUFID_VERTEX)]],
    const device float2* rectPos[[buffer(BUFID_RECT)]],
    constant uchar& drawMode [[buffer(BUFID_DRAWMODE)]],
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
    
    float angleA = vectorAngle(v0.pos, v1.pos);
    float2 localpos = rectPos[vid];  // pos in rect
    float2 pos = float2(mix(v0.radius, v1.radius, localpos.y) * localpos.x * 2, 0);

    bool isMidStart = localpos.y < 0.5 && v0.end == 0;
    bool isMidEnd = localpos.y > 0.5 && v1.end == 0;
    
    // miter ends
    if (isMidStart || isMidEnd) {
        float angleB = vectorAngle(isMidStart ? v0.pos : v1.pos,
                                   isMidStart ? vertices[iid - 1].pos : vertices[iid + 2].pos);
        if (isMidStart) angleB -= PI * sign(angleB);    // flip angle
        
        bool isClockwise = wrap_angle((angleB - angleA) * (isMidStart ? -1 : 1)) < 0;
        bool isInnerSide = (localpos.x > 0) == isClockwise;
        
        bool isMiter = (isMidStart && v0.joinType == 0) || (isMidEnd && v1.joinType == 0);
        
        if (isInnerSide || isMiter)
            pos *= rotateSkewMat(miterAngle(angleA, angleB), true);
    }
    
    pos += float2(0, localpos.y) * distance(v0.pos, v1.pos);      // add y
    pos *= rotateSkewMat(angleA - PIH);     // rotate
    pos += v0.pos;                          // add base pos
    
    // form out
    out.pos = float4(pos, 0, 1);
    out.pos.z = iid * 0.01;
    
    if (drawMode == 0) {
        // fill
        out.color = mix(v0.color, v1.color, localpos.y);
    } else if (drawMode == 1) {
        // wireframe
        out.color = float4(1,1,1,0.5);
        out.pos.z += 0.1;
    }
    
    return out;
}



vertex VtxOut vert_join (
     const device StrokeVertex* vertices [[buffer(BUFID_VERTEX)]],
     const device float2* roundPos [[buffer(BUFID_ROUND)]],
     constant ushort* joinIndices [[buffer(BUFID_JOINS)]],
     constant uchar& roundRes [[buffer(BUFID_ROUNDRES)]],
     constant uchar& drawMode [[buffer(BUFID_DRAWMODE)]],
     constant uchar& debug [[buffer(BUFID_DEBUG)]],
     uint vid [[vertex_id]],
     uint iid [[instance_id]]
) {
    VtxOut out;
    
    uint idx = joinIndices[iid];
    StrokeVertex v0 = vertices[idx];
    StrokeVertex vA = vertices[idx - 1];
    StrokeVertex vB = vertices[idx + 1];
    
    float2 pos = float2(0);
    
    float angleA = vectorAngle(vA.pos, v0.pos);
    float angleB = vectorAngle(v0.pos, vB.pos);

    if (vid == 0) {
        bool isClockwise = wrap_angle(angleB - angleA) < 0;
        
        pos = float2(1, 0) * v0.radius;
        pos *= isClockwise ? 1 : -1;
        
        pos *= rotateSkewMat(miterAngle(angleA, angleB), true);
        pos *= rotateSkewMat(angleA - PIH);
    } else {
        float dAngle = wrap_angle(angleB - angleA);
        float idx_ratio = (vid - 1.0) / roundRes;
        float angle = dAngle * idx_ratio;
        
        pos = float2(cos(angle), sin(angle)) * v0.radius;
        pos *= sign(dAngle);
        pos *= rotateSkewMat(angleA - PIH);
    }
    
    pos += v0.pos;
    out.pos = float4(pos, idx * 0.01, 1);
    
    if (drawMode == 0) {
        // fill
        out.color = debug ? float4(0.75, 0, 0, 1) : v0.color;
    } else {
        // wireframe
        out.color = float4(1,1,1,0.5);
        out.pos.z += 0.1;
    }

    return out;
}

/*
 for debug wireframes / points
 */
vertex VtxOut vert_debug (
    const device StrokeVertex* vertices[[buffer(BUFID_VERTEX)]],
    uint vid [[vertex_id]],
    constant uchar& drawStep [[buffer(BUFID_POINTSTEP)]]
) {
    VtxOut out;

    StrokeVertex vtx = vertices[vid];
    out.pos = float4(vtx.pos, 0.2, 1);

    if (drawStep == 0) {
        out.color = float4(1,1,1,1);
        out.ptsize = 16.0 * 0.5;
    } else if (drawStep == 1) {
        out.color = vtx.color;
        out.ptsize = 14.0 * 0.0;
        out.pos.z += 0.2;
    }

    return out;
}

fragment float4 frag_main(VtxOut in [[stage_in]]) {
    return in.color;
}
