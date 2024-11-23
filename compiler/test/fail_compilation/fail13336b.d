// REQUIRED_ARGS: -o-

int sx;
double sy;

/*
TEST_OUTPUT:
---
fail_compilation/fail13336b.d(20): Error: cannot `ref` return expression `cast(double)sx` because it is not an lvalue
        return sx;
               ^
fail_compilation/fail13336b.d(28): Error: cannot `ref` return expression `cast(double)sx` because it is not an lvalue
    return sx;
           ^
---
*/
ref f1(bool f)
{
    if (f)
        return sx;
    return sy;
}

ref f2(bool f)
{
    if (f)
        return sy;
    return sx;
}
