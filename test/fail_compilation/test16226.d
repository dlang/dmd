/* REQUIRED_ARGS: -dip25
   TEST_OUTPUT:
---
fail_compilation/test16226.d(14): Error: escaping reference to variable i
---
*/


// https://issues.dlang.org/show_bug.cgi?id=16226

ref int test() @safe
{
    int i;
    return foo(i);
}


ref foo(ref int bar) @safe
{
    return bar;
}


