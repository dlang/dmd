/* TEST_OUTPUT:
---
fail_compilation/test128.i(16): Error: unsigned __int128 not supported
    unsigned __int128 __res = (__int128) __X * __Y;
                      ^
fail_compilation/test128.i(16): Error: __int128 not supported
    unsigned __int128 __res = (__int128) __X * __Y;
                                       ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=23614

unsigned long long _mulx_u64(unsigned long long __X, unsigned long long __Y, unsigned long long *__P)
{
    unsigned __int128 __res = (__int128) __X * __Y;
    *__P = (unsigned long long) (__res >> 64);
    return (unsigned long long) __res;
}
