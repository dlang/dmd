/*
TEST_OUTPUT:
---
fail_compilation/fail95.d(20): Error: template fail95.A does not match any function template declaration. Candidates are:
fail_compilation/fail95.d(12):        fail95.A(alias T)(T)
fail_compilation/fail95.d(20): Error: template fail95.A(alias T)(T) cannot deduce template function from argument types !()(int)
---
*/

// Issue 142 - Assertion failure: '0' on line 610 in file 'template.c'

template A(alias T)
{
    void A(T) { T = 2; }
}

void main()
{
    int i;
    A(i);
    assert(i == 2);
}

