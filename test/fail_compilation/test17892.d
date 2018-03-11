/* REQUIRED_ARGS: -dip1000
TEST_OUTPUT:
---
fail_compilation/test17892.d(25): Error: returning `s.pointer1()` escapes a reference to local variable `s`
fail_compilation/test17892.d(27): Error: returning `s.pointer2()` escapes a reference to local variable `s`
---
*/


// https://issues.dlang.org/show_bug.cgi?id=17892

struct S
{
  @safe:
    int x;
    int[1] y;
    auto pointer1() return { return &x; }
    auto pointer2() return { return &y[0]; }
}

@safe int* testPointer(bool b)
{
    S s;
    if (b)
        return s.pointer1();
    else
        return s.pointer2();
}
