/* REQUIRED_ARGS: -preview=dip1000
   TEST_OUTPUT:
---
fail_compilation/test20569.d(20): Error: cannot take address of `scope` local `s1` in `@safe` function `main`
fail_compilation/test20569.d(24): Error: cannot take address of `scope` local `s2` in `@safe` function `main`
fail_compilation/test20569.d(28): Error: reference to local variable `x` assigned to non-scope `s3.pointer`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=20569

struct S
{
    int* pointer;
}

void main() @safe
{
    scope S s1;
    scope int** p1 = &s1.pointer;

    int x;
    S s2 = S(&x);
    auto p2 = &s2.pointer;

    S s3;
    auto p3 = &s3.pointer;
    s3.pointer = &x;
}
