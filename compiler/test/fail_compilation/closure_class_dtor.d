/*
TEST_OUTPUT:
---
fail_compilation/closure_class_dtor.d(19): Error: variable `closure_class_dtor.main.obj` has scoped destruction, cannot build closure
---
*/

/**
 * Test that capturing a class with destructor in a closure is forbidden.
 */

class C
{
    ~this() {}
}

void main()
{
    auto obj = new C();

    auto dg = () { return obj; }; // should be banned
}
