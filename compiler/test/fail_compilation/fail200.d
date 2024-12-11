// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail200.d(21): Deprecation: interface `fail200.DepClass` is deprecated
class Derived : DepClass
^
fail_compilation/fail200.d(21): Deprecation: interface `fail200.DepClass` is deprecated
class Derived : DepClass
^
---
*/

//import std.stdio;

deprecated interface DepClass
{
    void test();
}

class Derived : DepClass
{
    void test()
    {
        //writefln("Accessing what's deprecated!");
    }
}
