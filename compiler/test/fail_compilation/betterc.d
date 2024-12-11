/* REQUIRED_ARGS: -betterC
 * TEST_OUTPUT:
---
fail_compilation/betterc.d(18): Error: cannot use `throw` statements with -betterC
    throw new Exception("msg");
    ^
fail_compilation/betterc.d(23): Error: cannot use try-catch statements with -betterC
    try
    ^
fail_compilation/betterc.d(35): Error: `TypeInfo` cannot be used with -betterC
    auto ti = typeid(i);
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

void test3()
{
    int i;
    auto ti = typeid(i);
}
