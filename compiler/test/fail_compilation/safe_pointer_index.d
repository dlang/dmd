/*
TEST_OUTPUT:
---
fail_compilation/safe_pointer_index.d(13): Error: `@safe` function `f` cannot index pointer `x`
    int z = x[1];
             ^
---
*/

@safe void f(int* x)
{
    int y = x[0]; // allowed, same as *x
    int z = x[1];
}
