/*
TEST_OUTPUT:
---
fail_compilation/array1.d(17): Error: missing element in array initializer - got 3 elements, need 4
fail_compilation/array1.d(17):        use `, ...]` if intentional
---
*/

module m 2024;

extern (C) immutable int[4] a = [1,2,3,...];
static assert(a[3] == 0);

immutable int[4] b = [1,2,3,...];
static assert(b[3] == 0);

immutable int[4] c = [1,2,3];

