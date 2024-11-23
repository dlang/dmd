/*
TEST_OUTPUT:
---
fail_compilation/fail_isZeroInit.d(13): Error: type expected as second argument of __traits `isZeroInit` instead of `a`
    enum bool az = __traits(isZeroInit, a);
                   ^
---
*/
void test()
{
    int a = 3;
    // Providing a specific variable rather than a type isn't allowed.
    enum bool az = __traits(isZeroInit, a);
}
