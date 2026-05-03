/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array1.d(20): Deprecation: array initializer has 3 elements, but array length is 4
fail_compilation/array1.d(20):        use `, ...]` if intentional
fail_compilation/array1.d(23): Error: can only use `...` in static array initializer
fail_compilation/array1.d(24): Error: cannot use both indices and `...` in static array initializer
---
*/

module m 2024;

extern (C) immutable int[4] a = [1,2,3,...];
static assert(a[3] == 0);

immutable int[4] b = [1,2,3,...];
static assert(b[3] == 0);

int[4] c = [1,2,3];
int[4] d = [1:1]; // OK

int[] e = [1,...];
int[4] f = [2:1,...];
