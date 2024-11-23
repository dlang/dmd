/* TEST_OUTPUT:
---
fail_compilation/test10.d(12): Error: found `else` without a corresponding `if`, `version` or `debug` statement
    else
    ^
---
*/

void test(int i)
{
    ++i;
    else
        ++i;
}
