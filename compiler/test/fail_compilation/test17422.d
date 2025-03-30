/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test17422.d(23): Error: returning scope variable `p` is not allowed in a `@safe` function
---
*/
struct RC
{
    Object get() return @trusted
    {
        return cast(Object) &store[0];
    }

private:
    ubyte[__traits(classInstanceSize, Object)] store;
}

Object test() @safe
{
    RC rc;
    auto p = rc.get; // p must be inferred as scope variable, works for int*
    return p;
}
