/*
TEST_OUTPUT:
---
fail_compilation/__mutable2.d(17): Error: cannot access `__mutable` field `m` in `@safe` function `bar`
fail_compilation/__mutable2.d(22): Error: variable `__mutable2.foo.p` only fields can be `__mutable`
---
*/

struct T
{
    private __mutable int* m;
}

int* bar() @safe
{
    T s;
    return s.m; // error: cannot access `__mutable` field `m` in `@safe` function `bar`
}

void foo() @safe
{
    __mutable int* p; // error: only fields can be `__mutable`
}
