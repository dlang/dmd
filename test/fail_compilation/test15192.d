/*
REQUIRED_ARGS: -dip25
TEST_OUTPUT:
---
fail_compilation/test15192.d(14): Error: escaping reference to variable x
---
*/


// https://issues.dlang.org/show_bug.cgi?id=15192

ref int fun(ref int x) @safe
{
    ref int bar(){ return x; }
    return bar();
}

ref int fun2(return ref int x) @safe
{
    ref int bar(){ return x; }
    return bar();
}

