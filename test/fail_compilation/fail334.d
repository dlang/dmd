/*
TEST_OUTPUT:
---
fail_compilation/fail334.d(10): Error: @property functions can only have zero or one parameters
---
*/

struct S
{
    @property int foo(int a, int b, int c) { return 1; }
}
