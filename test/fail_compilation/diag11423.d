/*
TEST_OUTPUT:
---
fail_compilation/diag11423.d(9): Error: undefined identifier shared(Foo)
---
*/
void main()
{
    auto foo = new shared Foo();
}
