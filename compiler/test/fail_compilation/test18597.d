/* TEST_OUTPUT:
---
fail_compilation/test18597.d(30): Error: field `Unaligned.p` cannot modify misaligned pointers in `@safe` code
    u.p = new int;
    ^
fail_compilation/test18597.d(31): Error: field `Unaligned.p` cannot assign to misaligned pointers in `@safe` code
    Unaligned v = Unaligned(0, new int);
                               ^
fail_compilation/test18597.d(32): Error: field `Unaligned.p` cannot assign to misaligned pointers in `@safe` code
    Unaligned w = { p : new int };
                        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18597

@safe:

align(1)
struct Unaligned
{
align(1):
    ubyte filler;
    int* p;
}

void test()
{
    Unaligned u;
    u.p = new int;
    Unaligned v = Unaligned(0, new int);
    Unaligned w = { p : new int };
}
