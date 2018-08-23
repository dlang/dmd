// https://issues.dlang.org/show_bug.cgi?id=18672

/*
TEST_OUTPUT:
---
fail_compilation/fail18672.d(15): Error: cannot take address of local `a` in `@safe` function `fun`
---
*/

void fun2() @safe
{
    void fun()
    {
            int a;
            int* b = &a;                  // totally unsafe
    }
}
