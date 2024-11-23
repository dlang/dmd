/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test17892.d(33): Error: returning `s.pointer1()` escapes a reference to local variable `s`
        return s.pointer1();
                         ^
fail_compilation/test17892.d(35): Error: returning `s.pointer2()` escapes a reference to local variable `s`
        return s.pointer2();
                         ^
fail_compilation/test17892.d(37): Error: returning `s.pointer3()` escapes a reference to local variable `s`
        return s.pointer3();
                         ^
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
    auto pointer3() return { return &y[0..1][0]; }
}

@safe int* testPointer(int b)
{
    S s;
    if (b == 1)
        return s.pointer1();
    else if (b == 2)
        return s.pointer2();
    else
        return s.pointer3();
}
