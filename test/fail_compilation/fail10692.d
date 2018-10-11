// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail10692.d(26): Deprecation: accessing `alias this` of `struct A` is deprecated
fail_compilation/fail10692.d(27): Deprecation: accessing `alias this` of `struct A` is deprecated
---
*/

// https://issues.dlang.org/show_bug.cgi?id=10692

struct B
{
    int i;
}

struct A
{
    B b;
    deprecated alias b this;
}

void main()
{
    A a;
    a.i = 5; // Deprecated
    assert(a.i == 5); // Deprecated
}
