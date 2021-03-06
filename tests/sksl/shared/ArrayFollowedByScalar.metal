#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
struct Inputs {
};
struct Outputs {
    float4 sk_FragColor [[color(0)]];
};
fragment Outputs fragmentMain(Inputs _in [[stage_in]], bool _frontFacing [[front_facing]], float4 _fragCoord [[position]]) {
    Outputs _out;
    (void)_out;
    array<float, 3> rgb;
    float a;
    rgb[0] = 0.0;
    rgb[1] = 1.0;
    rgb[2] = 0.0;
    a = 1.0;
    _out.sk_FragColor = float4(rgb[0], rgb[1], rgb[2], a);
    return _out;
}
