// PERMUTE_ARGS:

void main()
{
    static assert(!__traits(compiles, mixin(" { void delegate(int x = 123) Dg1; } ")));
    static assert( __traits(compiles, mixin(" { void delegate(int x) Dg1; } ")));
    static assert(!__traits(compiles, mixin(" { void function(int x = 123) Dg2; } ")));
    static assert( __traits(compiles, mixin(" { void function(int x) Dg2; } ")));

    static assert(!__traits(compiles, mixin(" delegate (int x = 7) {} ")));
    static assert( __traits(compiles, mixin(" delegate (int x) {} ")));
    static assert(!__traits(compiles, mixin(" function (int x = 7) {} ")));
    static assert( __traits(compiles, mixin(" function (int x) {} ")));
    static assert(!__traits(compiles, mixin("          (int x = 7) {} ")));
    static assert( __traits(compiles, mixin("          (int x) {} ")));

    static void x(int a = 7) {}
    void y(int a = 7) {}

    static assert(is(typeof(&x) == void function(int)));
    static assert(is(typeof(&y) == void delegate(int)));
}
