/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test22227.d(16): Error: scope variable `foo` may not be returned
        return foo;
               ^
fail_compilation/test22227.d(18): Error: scope variable `foo` may not be returned
        return foo;
               ^
---
*/

int[] foo() @safe
{
    if (scope foo = [1])
        return foo;
    while (scope foo = [1])
        return foo;
    return [];
}
