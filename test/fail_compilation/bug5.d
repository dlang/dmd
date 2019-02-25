// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/bug5.d(9): Error: function `bug5.test1` no `return exp;` or `assert(0);` at end of function
---
*/

int test1()
{
    if (false)
        return 0;
}

