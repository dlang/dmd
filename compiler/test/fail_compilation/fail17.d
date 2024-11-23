/*
TEST_OUTPUT:
---
fail_compilation/fail17.d(17): Error: undefined identifier `B`
    mixin B!(T, A!(T));
    ^
fail_compilation/fail17.d(17): Error: mixin `fail17.A!int.A.B!(T, A!T)` is not defined
    mixin B!(T, A!(T));
    ^
fail_compilation/fail17.d(20): Error: template instance `fail17.A!int` error instantiating
A!(int) x;
^
---
*/
struct A(T)
{
    mixin B!(T, A!(T));
}

A!(int) x;
