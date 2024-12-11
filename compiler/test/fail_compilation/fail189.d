/*
TEST_OUTPUT:
---
fail_compilation/fail189.d(12): Error: undefined identifier `foo`
    foo(); // should fail
    ^
---
*/

void bar()
{
    foo(); // should fail
}

version(none):
void foo() {}
