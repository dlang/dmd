/*
TEST_OUTPUT:
---
fail_compilation/diag11423.d(11): Error: undefined identifier `Foo`
    auto foo = new shared Foo();
               ^
---
*/
void main()
{
    auto foo = new shared Foo();
}
