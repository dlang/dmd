/*
TEST_OUTPUT:
---
fail_compilation/fail13601.d(21): Error: variable `__ctfe` cannot be read at compile time
    static if (__ctfe) {}
               ^
fail_compilation/fail13601.d(22): Error: variable `__ctfe` cannot be read at compile time
    enum a = __ctfe ? "a" : "b";
             ^
fail_compilation/fail13601.d(23): Error: variable `__ctfe` cannot be read at compile time
    static int b = __ctfe * 2;
                   ^
fail_compilation/fail13601.d(24): Error: variable `__ctfe` cannot be read at compile time
    int[__ctfe] sarr;
                ^
---
*/

void test()
{
    static if (__ctfe) {}
    enum a = __ctfe ? "a" : "b";
    static int b = __ctfe * 2;
    int[__ctfe] sarr;
}
