version (D_SIMD)
{
    import core.simd;

    // https://issues.dlang.org/show_bug.cgi?id=19627
    enum int[4] fail19627 = cast(int[4])int4(0);
}
