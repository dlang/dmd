// REQUIRED_ARGS: -mcpu=avx2 -O
// DISABLED: win32 linux32 freebsd32

// https://issues.dlang.org/show_bug.cgi?id=21672

import core.simd;

int4 _mm_loadu_si16(const(void)* mem_addr) pure @trusted
{
    int r = *cast(short*)(mem_addr);
    short8 result = [0, 0, 0, 0, 0, 0, 0, 0];
    result.ptr[0] = cast(short)r;
    return cast(int4)result;
}
