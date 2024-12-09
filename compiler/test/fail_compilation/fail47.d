/*
TEST_OUTPUT:
---
fail_compilation/fail47.d(10): Error: variable `fail47._foo` is aliased to a function
int _foo;
    ^
---
*/
void foo() {}
int _foo;
alias _foo foo;

void main()
{
    foo = 1;
}
