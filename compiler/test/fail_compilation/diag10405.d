/*
TEST_OUTPUT:
---
fail_compilation/diag10405.d(12): Error: cannot return non-void from `void` function
    return 10;
    ^
---
*/

void main()
{
    return 10;
}
