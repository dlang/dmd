/*
TEST_OUTPUT:
---
fail_compilation/ice11926.d(11): Error: undefined identifier const(a)
fail_compilation/ice11926.d(12): Error: undefined identifier const(b)
---
*/

enum
{
    const a = 1,
    const b = 2
}
