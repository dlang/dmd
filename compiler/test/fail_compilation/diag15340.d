/*
TEST_OUTPUT:
---
fail_compilation/diag15340.d(15): Error: undefined identifier `undef1`
    auto a = undef1;
             ^
fail_compilation/diag15340.d(16): Error: undefined identifier `undef2`
    auto b = undef2;
             ^
---
*/

class C
{
    auto a = undef1;
    auto b = undef2;
}
