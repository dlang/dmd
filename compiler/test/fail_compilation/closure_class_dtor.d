/*
TEST_OUTPUT:
---
fail_compilation/closure_class_dtor.d(19): Error: scoped class variable `closure_class_dtor.main.obj` has destructor, cannot build closure
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
    scope obj = new C();

    auto dg = () { return obj; }; // should be banned
}
