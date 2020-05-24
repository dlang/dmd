
/*
TEST_OUTPUT:
---
fail_compilation/goto1.d(1010): Error: `return` statements cannot be in `finally` bodies
---
 */

void foo() @system;
void bar() @system;

#line 1000

void test2()
{
    try
    {
        foo();
    }
    finally
    {
        bar();
        return;
    }
}

