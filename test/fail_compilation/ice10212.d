/*
TEST_OUTPUT:
---
fail_compilation/ice10212.d(15): Deprecation: `(args) => { ... }` is a lambda that returns a delegate, not a multi-line lambda.
fail_compilation/ice10212.d(15):        Use `(args) { ... }` for a multi-statement function literal or use `(args) => () { }` if you intended for the lambda to return a delegate.
fail_compilation/ice10212.d(15): Error: Expected return type of `int`, not `int function() pure nothrow @nogc @safe`:
fail_compilation/ice10212.d(15):        Return type of `int` inferred here.
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
