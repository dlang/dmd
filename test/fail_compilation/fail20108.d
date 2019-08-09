// REQUIRED_ARGS: -dip1000
/*
TEST_OUTPUT:
---
fail_compilation/fail20108.d(13): Error: scope variable `x` may not be returned
---
*/

@safe auto test(scope int* x)
{
    int y = 69;
    x = &y; //bad
    return x;
}

void main()
{
    auto y = test(null);
}
