/*
REQUIRED_ARGS: -m64
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/staticarrayoverflow.d(18): Error: static array S[1879048192] size overflowed to 7516192768000
fail_compilation/staticarrayoverflow.d(18): Error: variable staticarrayoverflow.y size overflow
fail_compilation/staticarrayoverflow.d(19): Error: static array S[8070450532247928832] size overflowed to 0
fail_compilation/staticarrayoverflow.d(19): Error: variable staticarrayoverflow.a size overflow
---
*/

struct S
{
    int[1000] x;
}

S[0x7000_0000] y;
S[0x7000_0000_0000_0000] a;
