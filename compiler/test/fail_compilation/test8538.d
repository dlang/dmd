/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/test8538.d(108): Error: function `test8538.test1` cannot close over `scope` variable `x`
fail_compilation/test8538.d(126): Error: reference to local variable `i` assigned to non-scope parameter `x` calling `test0`
fail_compilation/test8538.d(128): Error: reference to local variable `i` assigned to non-scope parameter `x` calling `test2`
fail_compilation/test8538.d(129): Error: reference to local variable `i` assigned to non-scope parameter `x` calling `test3`
---
 */
// https://issues.dlang.org/show_bug.cgi?id=8538

/* `scope` variables cannot be referenced by a delegate that allocates a dynamic closure.
 * Cannot be inferred as `scope` either.
 */

#line 100

@safe:

int delegate() test0(int* x)
{
    return () { return *x; };
}

int delegate() test1(scope int* x)
{
    return () { return *x; };
}

auto test2(int* x)
{
    return () { return *x; };
}

int delegate() test3(int* x)
{
    return () { return *x; };
}

void mung()
{
    int i;
    test0(&i);
    test1(&i);
    test2(&i);
    test3(&i);
}
