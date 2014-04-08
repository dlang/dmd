// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail2659.d(11): Error: e2ir: cannot cast cast(void)1 of type void to type int
---
*/

int test2659()
{
    return (0, 1);
}
