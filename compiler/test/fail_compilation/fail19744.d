/*
TEST_OUTPUT:
---
fail_compilation/fail19744.d(10): Error: top-level function `test` has no `this` to which `return` can apply
int* test(return scope int* n) return
     ^
---
*/

int* test(return scope int* n) return
{
    return n;
}
