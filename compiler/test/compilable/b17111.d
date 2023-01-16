/*
TEST_OUTPUT:
---
compilable/b17111.d(15): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
compilable/b17111.d(16): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
---
*/

alias TestType = ubyte;

void test(immutable TestType a, immutable TestType b, TestType c)
{
    switch(c)
    {
        case a: break;
        case (cast(ushort)b): break;
        default: assert(false);
    }
}
