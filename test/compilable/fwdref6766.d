class Foo
{
    this(int x) { }
    void test(Foo foo = new Foo(1)) { }
}

struct Bar
{
    this(int x) { }
    void test(Bar bar = Bar(1)) { }
}
