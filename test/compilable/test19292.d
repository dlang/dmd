// https://issues.dlang.org/show_bug.cgi?id=19292

mixin("enum a = ", 87, ";");
static assert(a == 87);

int test()
{
    return mixin("1", 2);
}

void testit()
{
    static assert(test() == 12);
}
