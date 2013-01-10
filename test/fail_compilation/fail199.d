// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail199.d(19): Deprecation: class fail199.DepClass is deprecated
fail_compilation/fail199.d(19): Deprecation: class fail199.DepClass is deprecated
---
*/
// Issue 549 - A class derived from a deprecated class is not caught

import std.stdio;

deprecated class DepClass {
    void test() {
        writefln("Accessing what's deprecated!");
    }
}

class Derived : DepClass {}
