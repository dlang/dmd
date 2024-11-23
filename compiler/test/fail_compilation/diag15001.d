// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/diag15001.d(13): Error: undefined identifier `X`
    if (X x = 1)
    ^
---
*/

void main()
{
    if (X x = 1)
    {
    }
}
