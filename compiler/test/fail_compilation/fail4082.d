/*
TEST_OUTPUT:
---
fail_compilation/fail4082.d(24): Error: destructor `fail4082.Foo.~this` is not `nothrow`
    Foo f;
        ^
fail_compilation/fail4082.d(22): Error: function `fail4082.test1` may throw but is marked as `nothrow`
nothrow void test1()
             ^
fail_compilation/fail4082.d(35): Error: destructor `fail4082.Bar.~this` is not `nothrow`
nothrow void test2(Bar t)
                       ^
fail_compilation/fail4082.d(35): Error: function `fail4082.test2` may throw but is marked as `nothrow`
nothrow void test2(Bar t)
             ^
---
*/
struct Foo
{
    ~this() { throw new Exception(""); }
}
nothrow void test1()
{
    Foo f;

    goto NEXT;
NEXT:
    ;
}

struct Bar
{
    ~this() { throw new Exception(""); }
}
nothrow void test2(Bar t)
{
}
