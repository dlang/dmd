/*
TEST_OUTPUT:
---
fail_compilation/diag10359.d(12): Error: pointer slicing not allowed in safe functions
    auto a = p[0 .. 10];
              ^
---
*/

void foo(int* p) @safe
{
    auto a = p[0 .. 10];
}
