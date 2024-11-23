/*
TEST_OUTPUT:
---
fail_compilation/test16365.d(26): Error: `this` reference necessary to take address of member `f1` in `@safe` function `main`
    f = &S.f1;
        ^
fail_compilation/test16365.d(28): Error: cannot implicitly convert expression `&f2` of type `void delegate() pure nothrow @nogc @safe` to `void function() @safe`
    f = &f2;
        ^
fail_compilation/test16365.d(33): Error: `dg.funcptr` cannot be used in `@safe` code
    f = dg.funcptr;
        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=16365

struct S
{
    void f1() @safe { }
}

void main() @safe
{
    void function() @safe f;
    f = &S.f1;
    void f2() @safe { }
    f = &f2;

    void delegate() @safe dg;
    S s;
    dg = &s.f1;
    f = dg.funcptr;
}
