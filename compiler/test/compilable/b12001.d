void main()
{
    static assert(__traits(isSame, int, int));
    static assert(__traits(isSame, int[][], int[][]));
    static assert(__traits(isSame, bool*, bool*));

    static assert(!__traits(isSame, bool*, bool[]));
    static assert(!__traits(isSame, float, double));

    // https://github.com/dlang/dmd/issues/22442
    static assert(!__traits(isSame, int, const int));
    static assert(!__traits(isSame, Object, const Object));
}
