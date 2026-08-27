/*
TEST_OUTPUT:
---
fail_compilation/test19790.d(21): Error: function literal `() { }` is not callable using argument types `(int)`
fail_compilation/test19790.d(21):        function literal `() { }` is also known as `handlerOne`
fail_compilation/test19790.d(21):        expected 0 argument(s), not 1
fail_compilation/test19790.d(27): Error: template instance `test19790.match!(function () pure nothrow @nogc @safe
{
}
)` error instantiating
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19790 (github issue)

template match(handlers...)
{
    void go(int x)
    {
        alias handlerOne = handlers[0];
        handlerOne(x);
    }
}

void test()
{
    match!((){}).go(1);
}
