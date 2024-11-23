/*
TEST_OUTPUT:
---
fail_compilation/fail136.d(12): Error: `x"EFBBBF"` has no effect
    x"EF BB BF";
    ^
---
*/

void main()
{
    x"EF BB BF";
}
