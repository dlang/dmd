/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test18484.d(23): Error: returning `x.bar()` escapes a reference to local variable `x`
    auto x = S(); return x.bar();  // error
                              ^
fail_compilation/test18484.d(28): Error: escaping reference to stack allocated value returned by `S(0)`
    return S().bar();  // error
            ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18484

struct S
{
    int* bar() @safe return;
    int i;
}

int* test1() @safe
{
    auto x = S(); return x.bar();  // error
}

int* test2() @safe
{
    return S().bar();  // error
}
