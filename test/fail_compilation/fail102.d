/*
TEST_OUTPUT:
---
fail_compilation/fail102.d(11): Error: return statements cannot be in finally, scope(exit) or scope(success) bodies
fail_compilation/fail102.d(11): Error: cannot return non-void from void function
---
*/
void foo1()
{
    scope(exit)
        return 0;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail102.d(24): Error: return statements cannot be in finally, scope(exit) or scope(success) bodies
fail_compilation/fail102.d(24): Error: cannot return non-void from void function
---
*/
void foo2()
{
    scope(success)
        return 0;
}
