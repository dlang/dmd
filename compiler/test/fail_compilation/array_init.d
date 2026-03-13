/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array_init.d(10): Deprecation: array initializer has only 4 elements, but array length is 5
fail_compilation/array_init.d(10):        use an index in the array initializer (example: `[0: 10, 20, 30]`) to auto-fill the remaining elements
---
*/

immutable int[5] x = [1, 2, 3, 4];
