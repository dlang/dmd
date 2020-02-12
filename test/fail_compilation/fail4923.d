/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail4923.d(4): Deprecation: initialization of `immutable` variable from `static this` is deprecated.
fail_compilation/fail4923.d(4):        Use `shared static this` instead.
---
*/
#line 1
immutable int bar;
static this()
{
    bar = 42;
}
