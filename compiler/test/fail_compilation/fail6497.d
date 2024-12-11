/*
TEST_OUTPUT:
---
fail_compilation/fail6497.d(16): Error: cannot take address of local `n` in `@safe` function `main`
    auto b = &(0 ? n : n);
                   ^
fail_compilation/fail6497.d(16): Error: cannot take address of local `n` in `@safe` function `main`
    auto b = &(0 ? n : n);
                       ^
---
*/

void main() @safe
{
    int n;
    auto b = &(0 ? n : n);
}
