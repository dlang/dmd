/*
TEST_OUTPUT:
---
fail_compilation/test_isAnonymousUnion_errors.d(100): Error: expected 2 arguments for `isAnonymousUnion` but had 0
fail_compilation/test_isAnonymousUnion_errors.d(101): Error: expected 2 arguments for `isAnonymousUnion` but had 1
fail_compilation/test_isAnonymousUnion_errors.d(102): Error: expected 2 arguments for `isAnonymousUnion` but had 3
fail_compilation/test_isAnonymousUnion_errors.d(103): Error: first argument is not an aggregate type
fail_compilation/test_isAnonymousUnion_errors.d(104): Error: second argument to `__traits(isAnonymousUnion)` is not a field
---
*/

struct S
{
    union { int x; }
}

#line 100
enum a = __traits(isAnonymousUnion);
enum b = __traits(isAnonymousUnion, S);
enum c = __traits(isAnonymousUnion, S, S.x, S.x);
enum d = __traits(isAnonymousUnion, int, 5);
enum e = __traits(isAnonymousUnion, S, 42);
