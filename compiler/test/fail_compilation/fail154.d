/*
TEST_OUTPUT:
---
fail_compilation/fail154.d(18): Error: template instance `X!(MYP!int)` does not match template declaration `X(T : Policy!T, alias Policy)`
fail_compilation/fail154.d(18):        instantiated from here: `X!(MYP!int)`
fail_compilation/fail154.d(8):        Candidate match: X(T : Policy!T, alias Policy)
---
*/

#line 100

class X(T:Policy!(T), alias Policy)
{
    mixin Policy!(T);
}

template MYP(T)
{
    void foo(T);
}

X!(MYP!(int)) x;
