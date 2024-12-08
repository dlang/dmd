/*
TEST_OUTPUT:
---
fail_compilation/fail305.d(12): Error: cannot return non-void from `void` function
    return "a";
    ^
---
*/

void main()
{
    return "a";
}
