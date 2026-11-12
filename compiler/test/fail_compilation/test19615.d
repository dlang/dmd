// https://github.com/dlang/dmd/issues/19615

/*
TEST_OUTPUT:
---
fail_compilation/test19615.d(12): Error: `fun2` cannot be interpreted at compile time, because it has no available source code
fail_compilation/test19615.d(13):        compile time context created here
---
*/

int fun2();
int fun() { return fun2(); }
enum a = fun();
