// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail199.d(22): Deprecation: class `fail199.DepClass` is deprecated
fail_compilation/fail199.d(14):        `DepClass` is declared here
fail_compilation/fail199.d(22): Deprecation: class `fail199.DepClass` is deprecated
fail_compilation/fail199.d(14):        `DepClass` is declared here
---
*/

//import std.stdio;

deprecated class DepClass
{
    void test()
    {
        //writefln("Accessing what's deprecated!");
    }
}

class Derived : DepClass {}
