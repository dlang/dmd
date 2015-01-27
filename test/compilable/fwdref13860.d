// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
pure nothrow @nogc @safe void()
pure nothrow @nogc @safe void()
---
*/

struct Foo(Bar...)
{
    Bar bars;
    auto baz(size_t d)() {}
    pragma(msg, typeof(baz!0));
}

auto bar(S, R)(S s, R r)
{
    pragma(msg, typeof(Foo!().baz!0));
}

void main()
{
    int[] x;
    int[] y;
    x.bar(y);
}
