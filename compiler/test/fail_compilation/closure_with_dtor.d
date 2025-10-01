/*
TEST_OUTPUT:
---
fail_compilation/closure_with_dtor.d(19): Error: variable `closure_with_dtor.main.s` has scoped destruction, cannot build closure
---
*/

/**
 * Test that capturing a struct with destructor in a closure is forbidden.
 */

struct S
{
    ~this() {}
}

void main()
{
    S s;

    auto dg = () { return s; }; // should be banned
}
