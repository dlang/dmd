/* REQUIRED_ARGS: -O -m64
 * TEST_OUTPUT:
---
fail_compilation/test20903.d(16): Error: integer overflow
    return r / x;
    ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=20903

long test()
{
    long r = 0x8000_0000_0000_0000L;
    long x = -1L;
    return r / x;
}
