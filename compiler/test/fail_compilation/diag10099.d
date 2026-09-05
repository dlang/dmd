/*
TEST_OUTPUT:
---
fail_compilation/diag10099.d(16): Error: variable `diag10099.main.s` - default construction is disabled for type `S`
fail_compilation/diag10099.d(11):        because of `@disable this();` here
---
*/

struct S
{
    @disable this();
}

void main()
{
    S s;
}
