/* REQUIRED_ARGS: -betterC
 * TEST_OUTPUT:
---
fail_compilation/betterc.d(14): Error: Cannot use `throw` statements with -betterC
fail_compilation/betterc.d(19): Error: Cannot use try-catch statements with -betterC
fail_compilation/betterc.d(31): Error: `TypeInfo` cannot be used with -betterC
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

void test3()
{
    int i;
    auto ti = typeid(i);
}
