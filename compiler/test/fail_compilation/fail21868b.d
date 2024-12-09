/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/fail21868b.d(23): Error: returning `&s.x` escapes a reference to parameter `s`
    return &s.x;
           ^
fail_compilation/fail21868b.d(21):        perhaps change the `return scope` into `scope return`
int* test(ref return scope S s) @safe
                             ^
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
