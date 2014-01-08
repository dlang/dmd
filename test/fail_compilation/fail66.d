/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(12): Error: constructor fail66.C.this missing initializer for const field y
---
*/

class C
{
    const int y;

    this()
    {
    }
}
