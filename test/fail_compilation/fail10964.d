/*
TEST_OUTPUT:
---
fail_compilation/fail10964.d(30): Deprecation: Assignment of `ss` has no effect
fail_compilation/fail10964.d(32): Deprecation: Assignment of `sa` has no effect
fail_compilation/fail10964.d(30): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(31): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(32): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(35): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(36): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(37): Error: function `fail10964.S.__postblit` is not `nothrow`
fail_compilation/fail10964.d(24): Error: `nothrow` function `fail10964.foo` may throw
---
*/

struct S
{
    this(this)
    {
        throw new Exception("BOOM!");
    }
}

void foo() nothrow
{
    S    ss;
    S[1] sa;

    // TOKassign
    ss = ss;
    sa = ss;
    sa = sa;

    // TOKconstruct
    S    ss2 = ss;
    S[1] sa2 = ss;
    S[1] sa3 = sa;
}
