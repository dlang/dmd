/*
TEST_OUTPUT:
---
fail_compilation/fail6561.d(11): Error: undefined identifier `x`
    alias x this;   // should cause undefined identifier error
    ^
---
*/
struct S
{
    alias x this;   // should cause undefined identifier error
}

void main()
{
}
