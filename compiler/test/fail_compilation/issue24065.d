/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/issue24065.d(16): Error: assigning reference to local `r` to non-scope `dg` is not allowed in a `@safe` function
---
*/

// https://github.com/dlang/dmd/issues/24065

int delegate() @safe dg;

void f(ref int r) @safe
{
    int x;
    dg = () => x + r;
}
