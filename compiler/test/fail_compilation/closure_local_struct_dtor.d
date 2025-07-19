/*
TEST_OUTPUT:
---
fail_compilation/closure_local_struct_dtor.d(20): Error: variable `closure_local_struct_dtor.main.s` has scoped destruction, cannot build closure
---
*/

/**
 * Test that capturing a local struct with destructor in a closure is forbidden.
 */

void main()
{
    struct Local
    {
        ~this() {}
        int x;
    }

    Local s;

    auto dg = () { return s; }; // should be banned
}
