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
void test5854()
{
    auto arr1 = [S1(4, 4), S1(1, 3), S1(2, 9), S1(3, 22)].sort;

    foreach (i; 0 .. arr1.length - 1)
    {
        assert(arr1[i] < arr1[i + 1]);
    }

    auto arr2 = [S2(4, 4), S2(1, 3), S2(2, 9), S2(3, 22)].sort;

    foreach (i; 0 .. arr2.length - 1)
    {
        assert(arr2[i] < arr2[i + 1]);
    }
}
void main()
{
    test5854();
}
