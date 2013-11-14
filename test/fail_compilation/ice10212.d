/*
TEST_OUTPUT:
---
fail_compilation/ice10212.d(13): Error: mismatched function return type inference of int function() pure nothrow @safe and int
fail_compilation/ice10212.d(13): Error: cannot implicitly convert expression (__lambda1) of type int function() pure nothrow @safe to int
---
*/

int delegate() foo()
{
    // returns "int function() pure nothrow @safe function() pure nothrow @safe"
    // and it mismatches to "int delegate()"
    return () => {
        return 1;
    };
}
