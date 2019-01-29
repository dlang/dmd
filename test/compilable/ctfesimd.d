version (D_SIMD)
{
    import core.simd;

    // https://issues.dlang.org/show_bug.cgi?id=19627
    enum int[4] fail19627 = cast(int[4])int4(0);

    // https://issues.dlang.org/show_bug.cgi?id=19628
    enum ice19628a = int4.init[0];
    enum ice19628b = int4.init.array[0];
    enum ice19628c = (cast(int[4])int4.init.array)[0];

    // https://issues.dlang.org/show_bug.cgi?id=19629
    enum fail19629a = int4(0)[0];
    enum fail19629b = int4(0).array[0];
    enum fail19629c = (cast(int[4])int4(0).array)[0];

    // https://issues.dlang.org/show_bug.cgi?id=19630
    enum fail19630a = int4.init[1..2];
    enum fail19630b = int4.init.array[1..2];
    enum fail19630c = (cast(int[4])int4.init.array)[1..2];
    enum fail19630d = int4(0)[1..2];
    enum fail19630e = int4(0).array[1..2];
    enum fail19630f = (cast(int[4])int4(0).array)[1..2];
    enum fail19630g = (cast(int[4])int4.init)[1..2];
    enum fail19630h = (cast(int[4])int4(0))[1..2];
}
