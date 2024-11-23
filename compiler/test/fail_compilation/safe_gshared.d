/*
TEST_OUTPUT:
---
fail_compilation/safe_gshared.d(17): Error: `@safe` function `f` cannot access `__gshared` data `x`
    x++;
    ^
fail_compilation/safe_gshared.d(18): Error: `@safe` function `f` cannot access `__gshared` data `x`
    return x;
           ^
---
*/

__gshared int x;

@safe int f()
{
    x++;
    return x;
}
