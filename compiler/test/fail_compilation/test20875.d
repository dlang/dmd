// https://github.com/dlang/dmd/issues/20875

/*
TEST_OUTPUT:
---
fail_compilation/test20875.d(19): Error: expected 0 arguments, not 1 for non-variadic function type `pure nothrow @nogc @safe void()`
---
*/

struct S
{
    auto front() {}
}

void test()
{
    S res;
    ulong x;
    typeof(res.front)(x);
}
