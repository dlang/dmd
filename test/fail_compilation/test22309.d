/*
TEST_OUTPUT:
---
fail_compilation/test22309.d(19): Error: cannot take address of parameter `this` in `@safe` function `wrap`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22309

struct Wrap
{
    this(S* s) @safe {}
}

struct S
{
    Wrap wrap() @safe
    {
        return Wrap(&this);
    }
}
