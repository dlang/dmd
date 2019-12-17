/*
TEST_OUTPUT:
---
fail_compilation/fail47.d(13): Error: variable `fail47._foo` is aliased to a function
fail_compilation/fail47.d(13): Error: variable `fail47._foo` is aliased to a function
fail_compilation/fail47.d(13): Error: variable `fail47._foo` is aliased to a function
fail_compilation/fail47.d(18): Error: none of the overloads of `foo` are callable using argument types `(int)`, candidates are:
fail_compilation/fail47.d(12):        `fail47.foo()`
fail_compilation/fail47.d(13): Error: variable `fail47._foo` is aliased to a function
---
*/
void foo() {}
int _foo;
alias _foo foo;

void main()
{
    foo = 1;
}

