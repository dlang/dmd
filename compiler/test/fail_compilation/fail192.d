/*
TEST_OUTPUT:
---
fail_compilation/fail192.d(19): Error: outer function context of `fail192.foo` is needed to `new` nested class `fail192.foo.DummyClass`
        auto t = new T;
                 ^
fail_compilation/fail192.d(30): Error: template instance `fail192.X!(DummyClass)` error instantiating
    X!(DummyClass) x;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1336
// Internal error when trying to construct a class declared within a unittest from a templated class.
class X(T)
{
    void bar()
    {
        auto t = new T;
    }
}

void foo()
{
    class DummyClass
    {
    }

    //auto x = new X!(DummyClass);
    X!(DummyClass) x;
}
