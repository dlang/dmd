/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(10): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(11): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(12): Error: cannot infer static array length from `$`, provide an initializer
---
*/

int[$] arr1;
int[$] arr2 = void;
int[$][1] arr3 = 1;
