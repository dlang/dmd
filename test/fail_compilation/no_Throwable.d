/* 
DFLAGS:
REQUIRED_ARGS: -c -I=fail_compilation/extra-files/no_Throwable/
TEST_OUTPUT:
---
fail_compilation/no_Throwable.d(13): Error: Cannot use `throw` statements because `object.Throwable` was not declared
fail_compilation/no_Throwable.d(18): Error: Cannot use try-catch statements because `object.Throwable` was not declared
---
*/

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
