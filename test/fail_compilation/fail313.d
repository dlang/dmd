/*
TEST_OUTPUT:
---
fail_compilation/fail313.d(15): Error: module `imports.b313` is not accessible here, perhaps add `static import imports.b313;`
fail_compilation/fail313.d(22): Error: undefined identifier `core`
fail_compilation/fail313.d(27): Error: package `imports.pkg313` is not accessible here, perhaps add `static import imports.pkg313;`
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
