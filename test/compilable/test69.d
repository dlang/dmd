// PERMUTE_ARGS:

// Bugzilla 5735

struct A {}
void b() {}

void foo(bool cond) {}

void main()
{
    A a;
    int i;

    static assert(!__traits(compiles, assert(a)));
    static assert(!__traits(compiles, assert(i || a)));
    static assert(!__traits(compiles, assert(0 || a)));
    static assert(!__traits(compiles, assert(i && a)));
    static assert(!__traits(compiles, assert(1 && a)));

    static assert(!__traits(compiles, foo(a)));
    static assert(!__traits(compiles, foo(i || a)));
    static assert(!__traits(compiles, foo(0 || a)));
    static assert(!__traits(compiles, foo(i && a)));
    static assert(!__traits(compiles, foo(1 && a)));

    static assert(!__traits(compiles, assert(b)));
    static assert(!__traits(compiles, assert(i || b)));
    static assert(!__traits(compiles, assert(0 || b)));
    static assert(!__traits(compiles, assert(i && b)));
    static assert(!__traits(compiles, assert(1 && b)));

    static assert(!__traits(compiles, foo(b)));
    static assert(!__traits(compiles, foo(i || b)));
    static assert(!__traits(compiles, foo(0 || b)));
    static assert(!__traits(compiles, foo(i && b)));
    static assert(!__traits(compiles, foo(1 && b)));
}
