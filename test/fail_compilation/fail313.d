/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail313.d(16): Deprecation: module imports.b313 is not accessible here
fail_compilation/fail313.d(23): Deprecation: package core.stdc is not accessible here
fail_compilation/fail313.d(23): Deprecation: module core.stdc.stdio is not accessible here
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
