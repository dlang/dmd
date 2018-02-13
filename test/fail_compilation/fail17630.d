// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/b17630.d
/*
TEST_OUTPUT:
---
fail_compilation/fail17630.d(12): Deprecation: Symbol `b17630.Erase` is not visible from module `fail17630` because it is privately imported in module `a17630`
---
*/

void main()
{
    import imports.a17630 : Erase;
    assert(Erase == 2);
}
