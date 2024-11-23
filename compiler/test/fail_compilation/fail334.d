/*
TEST_OUTPUT:
---
fail_compilation/fail334.d(12): Error: properties can only have zero, one, or two parameter
    @property int foo(int a, int b, int c) { return 1; }
                  ^
---
*/

struct S
{
    @property int foo(int a, int b, int c) { return 1; }
}
