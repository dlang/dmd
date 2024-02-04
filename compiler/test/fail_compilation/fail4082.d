/*
TEST_OUTPUT:
---
fail_compilation/fail4082.d(14): Error: destructor `fail4082.Foo.~this` is not `nothrow`
fail_compilation/fail4082.d(12): Error: function `fail4082.test1` may throw but is marked as `nothrow`
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

/*
TEST_OUTPUT:
---
---
*/
struct Bar
{
    ~this() { throw new Exception(""); }
}
nothrow void test2(Bar t) // the throw happens in the caller, not the callee
{
}
