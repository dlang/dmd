struct S1
{
    long x1, x2;

    int opCmp(ref const S1 s) const
    {
        if (x2 - s.x2 != 0)
            return x2 < s.x2 ? -1 : 1;

        return x1 < s.x1 ? -1 : x1 == s.x1 ? 0 : 1;
    }
}

struct S2
{
    long x1, x2;

    int opCmp(in S2 s) const
    {
        if (x2 - s.x2 != 0)
            return x2 < s.x2 ? -1 : 1;

        return x1 < s.x1 ? -1 : x1 == s.x1 ? 0 : 1;
    }
}

extern (C) int structcmp(T)(scope T a, scope T b)
{
    extern (C) int cmp(scope const void* p1, scope const void* p2, scope void* ti)
    {
        return (cast(TypeInfo)ti).compare(p1, p2);
    }
    return cmp(&a, &b, cast(void*)typeid(T));
}

void test5854()
{
    alias Tuple(T...) = T;

    foreach (T; Tuple!(S1, S2))
    {
        assert(T(1, 3).structcmp(T(4, 4)) == -1);
        assert(T(1, 3).structcmp(T(4, 3)) == -1);
        assert(T(4, 3).structcmp(T(4, 3)) ==  0);
        assert(T(5, 3).structcmp(T(4, 3)) ==  1);
        assert(T(5, 4).structcmp(T(4, 3)) ==  1);
    }
}

void main()
{
    test5854();
}
