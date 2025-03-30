/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/fail21868b.d(19): Error: escaping a reference to parameter `s` by returning `&s.x` is not allowed in a `@safe` function
fail_compilation/fail21868b.d(17):        perhaps change the `return scope` into `scope return`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21868

struct S
{
    int x;
    int* y;
}

int* test(ref return scope S s) @safe
{
    return &s.x;
}
