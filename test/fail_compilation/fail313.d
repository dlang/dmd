/*
TEST_OUTPUT:
---
fail_compilation/fail313.d(17): Error: module `imports.b313` is not accessible here, perhaps add `static import imports.b313;`
fail_compilation/fail313.d(24): Deprecation: `imports.a313.core` is not visible from module `test313`
fail_compilation/fail313.d(24): Error: package `core.stdc` is not accessible here
fail_compilation/fail313.d(24): Error: module `core.stdc.stdio` is not accessible here, perhaps add `static import core.stdc.stdio;`
fail_compilation/fail313.d(29): Error: package `imports.pkg313` is not accessible here, perhaps add `static import imports.pkg313;`
---
*/
module test313;

import imports.a313;

void test1()
{
    imports.b313.bug();
    import imports.b313;
    imports.b313.bug();
}

void test2()
{
    core.stdc.stdio.printf("");
}

void test3()
{
    imports.pkg313.bug();
}
