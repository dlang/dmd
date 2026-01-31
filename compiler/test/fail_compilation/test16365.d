/*
TEST_OUTPUT:
---
fail_compilation/test16365.d(23): Error: taking address of member `f1` without `this` reference is not allowed in a `@safe` function
fail_compilation/test16365.d(25): Error: cannot implicitly convert expression `&f2` of type `void delegate() pure nothrow @nogc @safe` to `void function() @safe`
fail_compilation/test16365.d(29): Error: assigning address of variable `s` to `dg` with longer lifetime is not allowed in a `@safe` function
fail_compilation/test16365.d(30): Error: using `dg.funcptr` is not allowed in a `@safe` function
---
*/

module test16365 2024;

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
