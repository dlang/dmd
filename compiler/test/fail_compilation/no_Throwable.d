/*
DFLAGS:
REQUIRED_ARGS: -c
EXTRA_SOURCES: extra-files/minimal/object.d
TEST_OUTPUT:
---
fail_compilation/no_Throwable.d(18): Error: cannot use `throw` statements because `object.Throwable` was not declared
    throw new Exception("msg");
    ^
fail_compilation/no_Throwable.d(23): Error: cannot use try-catch statements because `object.Throwable` was not declared
    try
    ^
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
