/*
REQUIRED_ARGS: -o-
EXTRA_FILES: imports/fail17646.d
TEST_OUTPUT:
---
fail_compilation/imports/fail17646.d(10): Error: found `}` instead of statement
fail_compilation/fail17646.d(19): Error: template instance `allTestData!Modules` template `allTestData` is not defined
    allTestData!Modules;
    ^
fail_compilation/fail17646.d(22): Error: template instance `fail17646.runTests!""` error instantiating
alias fail = runTests!"";
             ^
---
*/
int runTests(Modules...)()
{
    import imports.fail17646;

    allTestData!Modules;
}

alias fail = runTests!"";
