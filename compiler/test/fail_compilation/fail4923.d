/*
TEST_OUTPUT:
---
fail_compilation/fail4923.d(19): Error: immutable variable `bar` initialization is not allowed in `static this`
    bar = 42;
    ^
fail_compilation/fail4923.d(19):        Use `shared static this` instead.
fail_compilation/fail4923.d(20): Deprecation: const variable `baz` initialization is not allowed in `static this`
    baz = 43;
    ^
fail_compilation/fail4923.d(20):        Use `shared static this` instead.
---
*/
// Line 1 starts here
immutable int bar;
const int baz; // https://issues.dlang.org/show_bug.cgi?id=24056
static this()
{
    bar = 42;
    baz = 43;
}
