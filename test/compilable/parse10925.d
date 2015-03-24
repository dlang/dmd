// REQUIRED_ARGS: -unittest -o-
// PERMUTE_ARGS:

class C
{
    private void foo() const {}
    private void bar() const pure @safe nothrow @nogc {}

    invariant() pure nothrow @safe @nogc
    {
        static assert(!__traits(compiles, foo()));
        static assert( __traits(compiles, bar()));
    }
    unittest() pure nothrow @safe @nogc
    {
        C c;
        static assert(!__traits(compiles, c.foo()));
        static assert( __traits(compiles, c.bar()));
    }
}
