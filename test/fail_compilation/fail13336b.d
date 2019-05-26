// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

int sx;
double sy;

/*
TEST_OUTPUT:
---
fail_compilation/fail13336b.d(17): Error: `cast(double)sx` is not an lvalue and cannot be modified
fail_compilation/fail13336b.d(25): Error: `cast(double)sx` is not an lvalue and cannot be modified
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
