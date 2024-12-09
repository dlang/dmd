// REQUIRED_ARGS: -preview=dip1000
/*
TEST_OUTPUT:
---
fail_compilation/fail20108.d(23): Error: address of variable `y` assigned to `x` with longer lifetime
    x = &y; //bad
      ^
fail_compilation/fail20108.d(24): Error: scope parameter `x` may not be returned
    return x;
           ^
fail_compilation/fail20108.d(31): Error: address of variable `y` assigned to `x` with longer lifetime
    x = &y; //bad
      ^
fail_compilation/fail20108.d(32): Error: scope variable `x` may not be returned
    return x;
           ^
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
