/*
REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
fail_compilation/staticarrayoverflow.d(39): Error: static array `S[cast(size_t)1879048192]` size overflowed to 7516192768000
S[0x7000_0000] y;
               ^
fail_compilation/staticarrayoverflow.d(39): Error: variable `staticarrayoverflow.y` size overflow
S[0x7000_0000] y;
               ^
fail_compilation/staticarrayoverflow.d(41): Error: static array `S[cast(size_t)8070450532247928832]` size overflowed to 8070450532247928832
S[0x7000_0000_0000_0000] a;
                         ^
fail_compilation/staticarrayoverflow.d(41): Error: variable `staticarrayoverflow.a` size overflow
S[0x7000_0000_0000_0000] a;
                         ^
fail_compilation/staticarrayoverflow.d(42): Error: static array `S[0][18446744073709551615LU]` size overflowed to 18446744073709551615
S[0][-1] b;
         ^
fail_compilation/staticarrayoverflow.d(42): Error: variable `staticarrayoverflow.b` size overflow
S[0][-1] b;
         ^
fail_compilation/staticarrayoverflow.d(43): Error: static array `S[0][cast(size_t)4294967295]` size overflowed to 4294967295
S[0][uint.max] c;
               ^
fail_compilation/staticarrayoverflow.d(43): Error: variable `staticarrayoverflow.c` size overflow
S[0][uint.max] c;
               ^
---
*/



struct S
{
    int[1000] x;
}

S[0x7000_0000] y;
S[0x100_0000/(4*1000 - 1)] z;
S[0x7000_0000_0000_0000] a;
S[0][-1] b;
S[0][uint.max] c;
