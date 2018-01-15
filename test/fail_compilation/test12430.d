/*
REQUIRED_ARGS: -m64
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/test12430.d(18): Error: simd operator must be an integer constant, not `op`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=12430

import core.simd;

void foo()
{
        float4 a;
        auto op = XMM.RSQRTPS;
        auto b = __simd(op, a);
}
