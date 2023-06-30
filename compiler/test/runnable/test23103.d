// https://issues.dlang.org/show_bug.cgi?id=23103
// Issue 23103 - static initialization of associative arrays is not implemented

auto get()
{
    long[int] aa;
    aa[0] = 1;
    aa[1] = 2;
    return aa;
}

auto globalAA = get();
immutable constAa = get();

void main()
{
    assert(globalAA[0] == 1);
    assert(globalAA[1] == 2);

    assert(constAa[0] == 1);
    assert(constAa[1] == 2);

    foreach (i; 0 .. 1000)
    {
        globalAA[i] = i + 1;
        assert(globalAA[i] == i + 1);
    }
}
