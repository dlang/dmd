/*
TEST_OUTPUT:
---
fail_compilation/test16523.d(13): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/test16523.d(13): Error: `case` variables have to be `const` or `immutable`
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
