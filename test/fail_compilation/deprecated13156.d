// REQUIRED_ARGS: -de -main

/*
TEST_OUTPUT:
---
fail_compilation/deprecated13156.d(14): Deprecation: function deprecated13156.I.f functions declared in an interface cannot be abstract
fail_compilation/deprecated13156.d(15): Deprecation: function deprecated13156.I.g functions declared in an interface cannot be abstract
fail_compilation/deprecated13156.d(16): Deprecation: function deprecated13156.I.h functions declared in an interface cannot be abstract
---
*/

interface I
{
    abstract void f();
    abstract { void g(); }
    abstract: void h();
}

