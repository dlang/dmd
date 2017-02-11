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

/**********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope2.d(302): Error: scope variable a assigned to return scope b
---
*/

#line 300
@safe int* test300(scope int* a, return scope int* b)
{
    b = a;
    return b;
}

/**********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope2.d(403): Error: scope variable a assigned to return scope c
---
*/

#line 400
@safe int* test400(scope int* a, return scope int* b)
{
    auto c = b; // infers 'return scope' for 'c'
    c = a;
    return c;
}

/**********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope2.d(504): Error: scope variable c may not be returned
---
*/

#line 500
@safe int* test500(scope int* a, return scope int* b)
{
    scope c = b; // does not infer 'return' for 'c'
    c = a;
    return c;
}



