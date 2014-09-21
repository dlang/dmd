/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail7472.d(17): Error: cannot cast expression o of type object.Object to int
fail_compilation/fail7472.d(18): Error: cannot cast expression i of type fail7472.I to int
---
*/

interface I {}

void main()
{
    Object o;
    I i;
    cast(void)cast(int)o;
    cast(void)cast(int)i;
}
