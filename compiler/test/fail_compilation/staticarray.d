/*
TEST_OUTPUT:
---
fail_compilation/static_import.d(8): Error: cannot infer static array length from `$`, provide an initializer
---
*/

int[$] arr;
