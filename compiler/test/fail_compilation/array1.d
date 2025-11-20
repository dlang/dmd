/*
TEST_OUTPUT:
---
fail_compilation/array1.d(13): Error: insufficient array initializers - has 3 elements, but needs 4
---
*/
extern (C) immutable int[4] a = [1,2,3,...];
static assert(a[3] == 0);

immutable int[4] b = [1,2,3,...];
static assert(b[3] == 0);

immutable int[4] c = [1,2,3];

