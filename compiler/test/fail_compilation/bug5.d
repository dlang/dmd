/*
TEST_OUTPUT:
---
fail_compilation/bug5.d(10): Error: function `bug5.test1` no `return exp;` or `assert(0);` at end of function
int test1()
    ^
---
*/

int test1()
{
    if (false)
        return 0;
}
