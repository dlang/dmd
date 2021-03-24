// https://issues.dlang.org/show_bug.cgi?id=21403

int[] cat11ret3(ref int[] s)
{
    s ~= 11;
    return [3];
}

int[] test(int[] val)
{
    (val ~= cat11ret3(val)) ~= 7;
    return val;
}

int main()
{
    static assert(test([2]) == [2, 11, 3, 7]);
    assert(test([2]) == [2, 11, 3, 7]);
    return 0;
}
