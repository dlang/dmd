/*
TEST_OUTPUT:
---
fail_compilation/diag10099.d(17): Error: variable `diag10099.main.s` - default construction is disabled for type `S`
    S s;
      ^
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
