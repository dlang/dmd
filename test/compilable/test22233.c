
// https://issues.dlang.org/show_bug.cgi?id=22233

int foo();

void test()
{
    (foo)();
}
