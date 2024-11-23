/*
TEST_OUTPUT:
---
fail_compilation/bug5b.d(10): Error: function `bug5b.test1` has no `return` statement, but is expected to return a value of type `int`
int test1()
    ^
---
*/

int test1()
{
}
