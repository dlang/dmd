/*
REQUIRED_ARGS: -preview=dip1000

TEST_OUTPUT:
---
fail_compilation/test23294.d(24): Error: scope variable `z` assigned to non-scope parameter `y` calling `f`
fail_compilation/test23294.d(18):        which is not `scope` because of `x = y`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23294
// Issue 23294 - [dip1000] parameter to parameter assignment leads to incorrect scope inference

@safe:

auto f(int* x, int* y)
{
    x = y;
    static int global; global++; // make sure it's not inferring scope from pure
}

void g(scope int* z)
{
    f(z, z); // passes
}
