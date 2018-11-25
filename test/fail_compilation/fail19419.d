/*
TEST_OUTPUT:
---
fail_compilation/fail19419.d(20): Error: none of the overloads of `this` are callable using argument types `(int)`, candidates are:
fail_compilation/fail19419.d(12):        `fail19419.B.this()`
fail_compilation/fail19419.d(14):        `fail19419.B.this(string s)`
---
*/

struct B
{
    @disable this();

    this(string s)
    {}
}

void main()
{
    auto b = B(3);
}
