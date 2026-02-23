/*
TEST_OUTPUT:
---
fail_compilation/test_isAnonymousUnion_errors.d(100): Error: expected 1 arguments for `isAnonymousUnion` but had 0
fail_compilation/test_isAnonymousUnion_errors.d(101): Error: expected 1 arguments for `isAnonymousUnion` but had 2
---
*/

struct S
{
    union { int x; }
    int y;
}

#line 100
enum a = __traits(isAnonymousUnion);
enum b = __traits(isAnonymousUnion, S, S.x);
