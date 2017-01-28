/*
REQUIRED_ARGS: -dip1000
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/retscope2.d(102): Error: scope variable s assigned to p with longer lifetime
fail_compilation/retscope2.d(107): Error: address of variable s assigned to p with longer lifetime
---
*/

#line 100
@safe foo1(ref char[] p, scope char[] s)
{
    p = s;
}

@safe bar1(ref char* p, char s)
{
    p = &s;
}


