/*
REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
fail_compilation/fail19898b.d(23): Error: cannot implicitly convert expression `m` of type `S` to `__vector(int[4])`
    foreach (i; m .. n)
                ^
fail_compilation/fail19898b.d(23): Error: expression `__key2 != __limit3` of type `__vector(int[4])` does not have a boolean value
    foreach (i; m .. n)
    ^
fail_compilation/fail19898b.d(23): Error: cannot cast expression `__key2` of type `__vector(int[4])` to `S`
    foreach (i; m .. n)
    ^
---
*/
struct S
{
    int a;
}

void f (__vector(int[4]) n, S m)
{
    foreach (i; m .. n)
        cast(void)n;
}
