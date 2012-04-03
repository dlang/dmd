interface Foo
{
    void call(T)(T t) {}
}

class Bar : Foo {}

void test()
{
    Bar bar;
    bar.call(2);
}
