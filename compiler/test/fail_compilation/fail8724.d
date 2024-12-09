// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail8724.d(18): Error: `object.Exception` is thrown but not caught
        throw new Exception("something");
        ^
fail_compilation/fail8724.d(16): Error: constructor `fail8724.Foo.this` may throw but is marked as `nothrow`
    this(int) nothrow
    ^
---
*/

struct Foo
{
    this(int) nothrow
    {
        throw new Exception("something");
    }
}
