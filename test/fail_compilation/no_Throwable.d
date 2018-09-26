/*
DFLAGS:
REQUIRED_ARGS: -c -I=fail_compilation/extra-files/no_Throwable/
TEST_OUTPUT:
---
fail_compilation/no_Throwable.d(15): Error: Cannot use `throw` statements because `object.Throwable` was not declared
fail_compilation/no_Throwable.d(20): Error: Cannot use try-catch statements because `object.Throwable` was not declared
---
*/

nothrow:

void test()
{
    throw new Exception("msg");
}

void test2()
{
    try
    {
        test();
    }
    catch (Exception e)
    {
    }
}
