// REQUIRED_ARGS: -dip1000
/*
TEST_OUTPUT:
---
fail_compilation/fail20108.d(14): Error: address of variable `y` assigned to `x` with longer lifetime
fail_compilation/fail20108.d(22): Error: address of variable `y` assigned to `x` with longer lifetime
fail_compilation/fail20108.d(23): Error: scope variable `x` may not be returned
---
*/

@safe auto test(scope int* x)
{
    int y = 69;
    x = &y; //bad
    return x;
}

@safe auto test2()
{
    scope int* x;
    int y = 69;
    x = &y; //bad
    return x;
}

void main()
{
    auto y = test(null);
    auto z = test2();
}
