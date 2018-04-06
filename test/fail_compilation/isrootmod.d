/*
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/isrootmod.d(10): Error: __traits(isRootModule, <module>) not implemented
fail_compilation/isrootmod.d(10):        while evaluating `pragma(msg, __traits(isRootModule, 0))`
---
*/

pragma(msg, __traits(isRootModule, 0));
