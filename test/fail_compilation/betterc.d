/* REQUIRED_ARGS: -betterC
 * TEST_OUTPUT:
---
fail_compilation/betterc.d(11): Error: Cannot use `throw` statements with -betterC
fail_compilation/betterc.d(16): Error: Cannot use try-catch statements with -betterC
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
