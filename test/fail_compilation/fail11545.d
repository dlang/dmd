/*
TEST_OUTPUT:
---
fail_compilation/fail11545.d(17): Error: cannot implicitly convert expression (__lambda5) of type int delegate() pure nothrow @nogc @safe to int function()
fail_compilation/fail11545.d(17): Error: cannot implicitly convert expression (__lambda5) of type int delegate() pure nothrow @nogc @safe to int function()
---
*/

class C
{
    int x = 42;

    int function() f1 = function() {
        return x;
    };

    int function() f2 = {
        return x;
    };
}
