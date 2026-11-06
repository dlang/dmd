/* REQUIRED_ARGS: -O -m64
 */

// no longer caught at compile time, because of https://github.com/dlang/dmd/issues/24084
// originally reported by https://issues.dlang.org/show_bug.cgi?id=20903

long test()
{
    long r = 0x8000_0000_0000_0000L;
    long x = -1L;
    return r / x;
}
