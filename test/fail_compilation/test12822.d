/*
---
fail_compilation/test12822.d(11): Error: cannot modify delegate pointer in @safe code dg.ptr
fail_compilation/test12822.d(12): Error: cannot modify delegate function pointer in @safe code dg.ptr
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
