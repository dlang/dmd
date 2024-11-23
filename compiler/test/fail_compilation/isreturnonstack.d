/*
TEST_OUTPUT:
---
fail_compilation/isreturnonstack.d(15): Error: argument to `__traits(isReturnOnStack, int)` is not a function
enum b = __traits(isReturnOnStack, int);
         ^
fail_compilation/isreturnonstack.d(16): Error: expected 1 arguments for `isReturnOnStack` but had 2
enum c = __traits(isReturnOnStack, test, int);
         ^
---
*/

int test() { return 0; }

enum b = __traits(isReturnOnStack, int);
enum c = __traits(isReturnOnStack, test, int);
