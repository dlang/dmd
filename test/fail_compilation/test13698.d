
// REQUIRED_ARGS: -m64
// fail_compilation/test13698.d(12): Error: constant expression expected, not cast(void)b

// https://issues.dlang.org/show_bug.cgi?id=13698

import core.simd;

void main() {
        float4 a;
        ubyte b = 0;
        a = __simd(XMM.SHUFPS, a, b);
}
