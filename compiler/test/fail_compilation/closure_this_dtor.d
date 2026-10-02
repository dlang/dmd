/*
TEST_OUTPUT:
---
fail_compilation/closure_this_dtor.d(16): Error: variable `closure_this_dtor.S.foo.this` has scoped destruction, cannot build closure
---
*/

/**
 * Test that capturing `this` of a struct with destructor in a closure is forbidden.
 */

struct S
{
    ~this() {}

    void foo()
    {
        auto dg = () { return this; }; // should be banned
    }
}

void main()
{
    S s;
    s.foo();
}
