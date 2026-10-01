/*
TEST_OUTPUT:
---
fail_compilation/fail22925.d(15): Error: integer constant expression expected instead of `"s"`
fail_compilation/fail22925.d(15): Error: integer constant expression expected instead of `"z"`
fail_compilation/fail22925.d(23): Error: `s` must be of integral or string type, it is a `real`
fail_compilation/fail22925.d(35): Error: cannot implicitly convert expression `2.8` of type `double` to `int`
fail_compilation/fail22925.d(35): Error: cannot implicitly convert expression `4.2` of type `double` to `int`
---
*/
void test1(string s)
{
    switch (s)
    {
        case "s": .. case "z":
            break;
        default:
            break;
    }
}
void test2(real s)
{
    switch (s)
    {
        case 1.0: .. case 2.7:
            break;
        default:
            break;
    }
}
void test3(int s)
{
    switch (s)
    {
        case 2.8: .. case 4.2:
            break;
        default:
            break;
    }
}
