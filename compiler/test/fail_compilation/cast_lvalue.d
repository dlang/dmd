/*
REQUIRED_ARGS: -wo -w
TEST_OUTPUT:
---
fail_compilation/cast_lvalue.d(18): Warning: using cast from `int` to `immutable(int)` as an lvalue is obsolete
fail_compilation/cast_lvalue.d(20): Warning: using cast from `const(int)` to `immutable(int)` as an lvalue is obsolete
fail_compilation/cast_lvalue.d(24): Warning: using cast from `const(int)` to `int` as an lvalue is obsolete
fail_compilation/cast_lvalue.d(26): Warning: using cast from `const(int)` to `immutable(int)` as an lvalue is obsolete
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

void main()
{
    int x;
    auto p = &cast(const int) x; // OK
    auto r = &cast(immutable int) x;
    x++; // would mutate *r
    auto s = &cast(immutable) *p;
    auto t = &cast(shared) x; // allowed

    const int y;
    auto q = &cast(int) y;
    *q = 5; // would mutate y
    auto u = &cast(immutable) y;

    shared int z;
    auto v = &cast(int) z; // allowed
}
