/*
DFLAGS:
REQUIRED_ARGS: -conf= -Ifail_compilation/extra-files/minimal
TEST_OUTPUT:
---
fail_compilation/fail19319b.d(16): Error: `object._d_pow` not found. The current runtime does not support the ^^ operator, or the runtime is corrupt.
fail_compilation/fail19319b.d(17): Error: `object._d_sqrt` not found. The current runtime does not support the operation `^^ 0.5`, or the runtime is corrupt.
---
*/

void test19319(int x)
{
    static assert(!__traits(compiles, 7 ^^ x));
    static assert(!__traits(compiles, x ^^= 7));

    int i = 7 ^^ x;
    x ^^= 0.5;
}
