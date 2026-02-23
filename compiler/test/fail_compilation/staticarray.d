/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(8): Error: cannot infer static array length from `$`, provide an initializer
---
*/

int[$] arr;
