/*
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/retscope.d(16): Error: scope variable p may not be returned
fail_compilation/retscope.d(26): Error: escaping reference to local variable j
---
*/


int* foo1(return scope int* p) { return p; } // ok

int* foo2()(scope int* p) { return p; }  // ok, 'return' is inferred
alias foo2a = foo2!();

int* foo3(scope int* p) { return p; }   // error

int* foo4(bool b)
{
    int i;
    int j;

    int* nested1(scope int* p) { return null; }
    int* nested2(return scope int* p) { return p; }

    return b ? nested1(&i) : nested2(&j);
}
