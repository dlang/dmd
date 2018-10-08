// https://issues.dlang.org/show_bug.cgi?id=19292

int test()
{
    mixin("enum x = ", 7, ";");
    return mixin("1", x, 2U);
}

void testit()
{
    static assert(test() == 172);
}
