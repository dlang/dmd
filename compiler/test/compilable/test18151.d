// https://issues.dlang.org/show_bug.cgi?id=18151

/*
TEST_OUTPUT:
---
value
---
*/

void test()(auto ref Inner inner)
{
    pragma(msg, __traits(isRef, inner) ? "ref" : "value");
}

struct Inner
{
}

struct Outer
{
    Inner inner;
    Inner get() { return inner; }
    alias get this;
}

void bug()
{
    Outer outer;
    test(outer);
}
