/*
TEST_OUTPUT:
---
fail_compilation/test_isOverlapped_errors.d(100): Error: expected 1 arguments for `isOverlapped` but had 0
fail_compilation/test_isOverlapped_errors.d(101): Error: expected 1 arguments for `isOverlapped` but had 2
---
*/

struct S
{
    union { int x; }
    int y;
}

#line 100
enum a = __traits(isOverlapped);
enum b = __traits(isOverlapped, S, S.x);
