// https://issues.dlang.org/show_bug.cgi?id=19292

int test()
{
    return mixin("1", 2);
}

void testit()
{
    static assert(test() == 12);
}
