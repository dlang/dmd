/*
TEST_OUTPUT:
---
fail_compilation/ice13225.d(105): Error: mixin `ice13225.S.M!(function (S __param_0) pure nothrow @nogc @safe => 0)` does not match template declaration `M(T)`
fail_compilation/ice13225.d(105):        instantiated from here: `M!(function (S __param_0) pure nothrow @nogc @safe => 0)`
fail_compilation/ice13225.d(101):        Candidate match: M(T)
fail_compilation/ice13225.d(109): Error: undefined identifier `undefined`
---
*/

#line 100

mixin template M(T) {}

struct S
{
    mixin M!((typeof(this)) => 0);
}
struct T
{
    mixin M!(() => undefined);
}
