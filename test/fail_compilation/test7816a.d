interface Foo
{
    void call(T)(T t) {}
}

void test()
{
    Foo foo;
    foo.call(2);
}
