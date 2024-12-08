// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail199.d(24): Deprecation: class `fail199.DepClass` is deprecated
class Derived : DepClass {}
^
fail_compilation/fail199.d(24): Deprecation: class `fail199.DepClass` is deprecated
class Derived : DepClass {}
^
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
