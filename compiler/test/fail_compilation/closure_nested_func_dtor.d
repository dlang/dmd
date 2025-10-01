/*
TEST_OUTPUT:
---
fail_compilation/closure_nested_func_dtor.d(19): Error: variable `closure_nested_func_dtor.main.s` has scoped destruction, cannot build closure
---
*/

/**
 * Test that capturing a variable with destructor in a closure inside a nested function is forbidden.
 */

struct S
{
    ~this() {}
}

void main()
{
    S s;

    void nested()
    {
        auto dg = () { return s; }; // should be banned
    }

    nested();
}
