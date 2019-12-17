// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/b17630.d
/*
TEST_OUTPUT:
---
fail_compilation/fail17630.d(12): Error: module `a17630` import `Erase` not found, did you mean variable `b17630.Erase`?
---
*/

void main()
{
    import imports.a17630 : Erase;
    assert(Erase == 2);
}
