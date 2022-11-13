/* REQUIRED_ARGS: -m64
DISABLED: win32 linux32 osx32 freebsd32
TEST_OUTPUT:
---
fail_compilation/fail17105.d(20): Error: missing 4th parameter to `__simd()`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17105

module foo;
import core.simd;

struct bug {
    version (D_SIMD)
    {
        float4 value;
        auto normalize() {
            value = cast(float4) __simd(XMM.DPPS, value, value, 0xFF);
            value = cast(float4) __simd(XMM.DPPS, value, value);
        }
    }
}

/*
https://www.felixcloutier.com/x86/dpps

66 0F 3A 40 /r ib DPPS xmm1, xmm2/m128, imm8
*/
