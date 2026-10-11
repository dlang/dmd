/*
DFLAGS:
REQUIRED_ARGS: -conf= -betterC -c -Icompilable/extra-files/ctfe_only_new
TEST_OUTPUT:
---
fail_compilation/ctfe_only_new.d(21): Error: `object._d_newclassT` not found. The current runtime does not support new class, or the runtime is corrupt.
---
*/

// Counterpart of compilable/ctfe_only_new.d: without `@__ctfe` the `new` is lowered
// to the `_d_newclassT` runtime hook, which this minimal runtime does not have.

class C
{
    int x;
    this(int x) { this.x = x; }
}

int make(int x)
{
    auto c = new C(x);
    return c.x;
}
