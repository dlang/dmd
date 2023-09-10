/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/cast_lvalue.d(16): Error: cannot use cast from `int` to `immutable(int)` as an lvalue in @safe code
fail_compilation/cast_lvalue.d(18): Error: cannot use cast from `const(int)` to `immutable(int)` as an lvalue in @safe code
fail_compilation/cast_lvalue.d(23): Error: cannot use cast from `const(int)` to `int` as an lvalue in @safe code
fail_compilation/cast_lvalue.d(25): Error: cannot use cast from `const(int)` to `immutable(int)` as an lvalue in @safe code
---
*/

void main() @safe
{
    int x;
    auto p = &cast(const int) x; // OK
    auto r = &cast(immutable int) x;
    x++; // would mutate *r
    auto s = &cast(immutable) *p;
    auto t = &cast(shared) x; // TODO

    const int y;
    x = cast() y; // OK, rvalue
    auto q = &cast(int) y;
    *q = 5; // would mutate y
    auto u = &cast(immutable) y;

    shared int z;
    auto v = &cast(int) z; // TODO
    auto w = &cast(shared) x; // TODO
}
