/*
TEST_OUTPUT:
---
fail_compilation/test16365.d(21): Error: cannot implicitly convert expression `& f1` of type `void*` to `void function() @safe`
fail_compilation/test16365.d(23): Error: cannot implicitly convert expression `&f2` of type `void delegate() pure nothrow @nogc @safe` to `void function() @safe`
fail_compilation/test16365.d(27): Deprecation: address of variable `s` assigned to `dg` with longer lifetime
fail_compilation/test16365.d(28): Error: `dg.funcptr` cannot be used in `@safe` code
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
