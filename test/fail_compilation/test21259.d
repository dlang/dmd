// https://issues.dlang.org/show_bug.cgi?id=21259
// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/test21259.d(39): Deprecation: field `width` of struct `Foo` is deprecated
fail_compilation/test21259.d(40): Deprecation: field `width` of struct `Foo2` is deprecated
fail_compilation/test21259.d(41): Deprecation: field `bar` of struct `Foo3` is deprecated
fail_compilation/test21259.d(42): Deprecation: field `width` of struct `Foo4` is deprecated
---
*/

struct Foo
{
    int bar;
    deprecated alias width = bar;
}

struct Foo2
{
    deprecated int bar;
    deprecated alias width = bar;
}

struct Foo3
{
    deprecated int bar;
}

struct Foo4
{
    int bar;
deprecated:
    alias width = bar;
}

void main()
{
    Foo a = { width : 100};
    Foo2 b = { width : 100};
    Foo3 c = { bar : 100};
    Foo4 d = { width : 100};
}
