/*
REQUIRED_ARGS: -de

TEST_OUTPUT:
---
fail_compilation/test20763.d(21): Deprecation: type `ulong` has no value
fail_compilation/test20763.d(21):        perhaps use `ulong.init` instead
fail_compilation/test20763.d(22): Deprecation: type `ulong` has no value
fail_compilation/test20763.d(22):        perhaps use `ulong.init` instead
fail_compilation/test20763.d(23): Error: type `ulong` has no value
fail_compilation/test20763.d(24): Error: type `ulong` has no value
fail_compilation/test20763.d(25): Error: type `ulong` has no value
fail_compilation/test20763.d(26): Error: type `ulong` has no value
---
*/

// https://github.com/dlang/dmd/issues/20763
void test()
{
    alias I = ulong;
    alias U0 = typeof(I + 1u);
    alias U1 = typeof(1 - I);
    alias U2 = typeof(+I);
    alias U3 = typeof(I * 1);
    alias U4 = typeof(I << 1);
    alias U5 = typeof(I | 1);
}
