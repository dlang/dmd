// https://issues.dlang.org/show_bug.cgi?id=20828

/*
TEST_OUTPUT:
---
tuple("scope", "@safe")
---
*/

struct Struct
{
    void fun() @safe scope;
}

pragma(msg, __traits(getFunctionAttributes, Struct.fun));
