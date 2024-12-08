/*
TEST_OUTPUT:
---
fail_compilation/fail19098.d(20): Error: cannot modify struct instance `a` of type `A` because it contains `const` or `immutable` members
    a = b;
    ^
---
*/

struct A
{
    const int a;
    this(int) {}
}

void main()
{
    A a = A(2);
    A b = A(3);
    a = b;
}
