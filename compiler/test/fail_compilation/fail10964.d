/*
TEST_OUTPUT:
---
fail_compilation/fail10964.d(42): Error: function `fail10964.S.__postblit` is not `nothrow`
    ss = ss;
         ^
fail_compilation/fail10964.d(43): Error: function `fail10964.S.__postblit` is not `nothrow`
    sa = ss;
       ^
fail_compilation/fail10964.d(44): Error: function `fail10964.S.__postblit` is not `nothrow`
    sa = sa;
       ^
fail_compilation/fail10964.d(47): Error: function `fail10964.S.__postblit` is not `nothrow`
    S    ss2 = ss;
         ^
fail_compilation/fail10964.d(48): Error: function `fail10964.S.__postblit` is not `nothrow`
    S[1] sa2 = ss;
         ^
fail_compilation/fail10964.d(49): Error: function `fail10964.S.__postblit` is not `nothrow`
    S[1] sa3 = sa;
         ^
fail_compilation/fail10964.d(36): Error: function `fail10964.foo` may throw but is marked as `nothrow`
void foo() nothrow
     ^
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
