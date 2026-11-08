// REQUIRED_ARGS: -O
// PERMUTE_ARGS:
// https://github.com/dlang/dmd/issues/24111

pragma(inline, false)
long f(ulong a, long b)
{
    return (a & 0xFFFF_FFFF) + (b <= 0);
}

void main()
{
    assert(f(5, long.min) == 6);
    assert(f(5, -1) == 6);
    assert(f(5, 0) == 6);
    assert(f(5, 1) == 5);
    assert(f(5, long.max) == 5);
    assert(f(0, 0) == 1);
    assert(f(0x1_FFFF_FFFF, 0) == 0x1_0000_0000);
    assert(f(ulong.max, 1) == 0xFFFF_FFFF);
}
