/*
TEST_OUTPUT:
---
fail_compilation/ice9291.d(12): Error: undefined identifier `F`
    throw new F();
          ^
---
*/

void main() nothrow
{
    throw new F();
}
