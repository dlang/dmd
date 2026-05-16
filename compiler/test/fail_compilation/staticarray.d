/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(13): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(14): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(15): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(16): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation/staticarray.d(17): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation/staticarray.d(18): Error: cannot infer static array length from `$`, provide an initializer
---
*/

int[$] arr1;
int[$] arr2 = void;
int[$][1] arr3 = 1;
int[$]* arr4 = [1, 2];
auto[$]* arr5 = [1, 2];
auto[$] arr6;
