void test0(E)(lazy E e) @nogc nothrow
{
    auto v = e();
}
void test1(E)(lazy E e) @nogc nothrow
{
    e()();
}

void foo() @nogc nothrow
{
    test0(42);
    test0(new Exception(null));
}
void bar()
{
    auto x = new Exception(null);
    test1(() { throw x; });
}
