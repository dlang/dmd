// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail2659.d(13): Warning: The comma operator will be deprecated
fail_compilation/fail2659.d(14): Warning: The comma operator will be deprecated
---
*/

void main()
{
    int x;
    x = 1, 2;
    x = 1, x = 2;
}
