
// REQUIRED_ARGS: -m64
// https://issues.dlang.org/show_bug.cgi?id=13698
/*
TEST_OUTPUT:
---
fail_compilation/test13698.d(16): Error: constant expression expected, not `cast(void)b`
---
*/

import core.simd;

void main() {
        float4 a;
        ubyte b = 0;
        a = __simd(XMM.SHUFPS, a, b);
}
