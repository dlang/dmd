/*
DFLAGS:
REQUIRED_ARGS: -c -I=fail_compilation/extra-files/no_Throwable/
TEST_OUTPUT:
---
fail_compilation/no_Throwable2.d(11): Error: function `no_Throwable2.notNoThrow` must be `nothrow` if compiling without support for exceptions (e.g. -betterC)
fail_compilation/no_Throwable2.d(15): Error: function `no_Throwable2.S.notNowThrow` must be `nothrow` if compiling without support for exceptions (e.g. -betterC)
---
*/

void notNoThrow() {}

struct S
{
    void notNowThrow() { }
}
