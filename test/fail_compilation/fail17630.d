// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/b17630.d
/*
TEST_OUTPUT:
---
fail_compilation/fail17630.d(12): Deprecation: Symbol `Erase` is not visible because it is privately imported
---
*/

void main()
{
    import imports.a17630 : Erase;
    assert(Erase == 2);
}
