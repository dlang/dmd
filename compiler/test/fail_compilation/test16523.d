/*
TEST_OUTPUT:
---
fail_compilation/test16523.d(14): Error: `case` variables have to be `const` or `immutable`
    case b: return;
    ^
---
*/

void test(int a, int b)
{
    switch (a)
    {
    case b: return;
    default: assert(0);
    }
}
