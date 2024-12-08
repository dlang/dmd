/*
EXTRA_FILES: imports/a313.d imports/b313.d imports/pkg313/package.d
TEST_OUTPUT:
---
fail_compilation/fail313.d(22): Error: undefined identifier `b313` in package `imports`, perhaps add `static import imports.b313;`
    imports.b313.bug();
           ^
fail_compilation/fail313.d(29): Error: undefined identifier `core`
    core.stdc.stdio.printf("");
    ^
fail_compilation/fail313.d(34): Error: undefined identifier `pkg313` in package `imports`, perhaps add `static import imports.pkg313;`
    imports.pkg313.bug();
           ^
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
