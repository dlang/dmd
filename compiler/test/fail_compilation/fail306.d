/*
TEST_OUTPUT:
---
fail_compilation/fail306.d(13): Error: cannot perform array operations on `void[]` arrays
    x[] = -x[];
        ^
---
*/

void bar()
{
    void [] x;
    x[] = -x[];
}
