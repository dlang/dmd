/*
TEST_OUTPUT:
---
fail_compilation/test12822.d(17): Error: cannot modify delegate pointer in `@safe` code `dg.ptr`
    dg.ptr = &i;
    ^
fail_compilation/test12822.d(18): Error: `dg.funcptr` cannot be used in `@safe` code
    dg.funcptr = &func;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=12822
void test2(int delegate() dg) @safe
{
    static int i;
    dg.ptr = &i;
    dg.funcptr = &func;
}

int func();
