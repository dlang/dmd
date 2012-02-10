// PERMUTE_ARGS:

class C {}
class D : C {}

void dynamicarrays()
{
    C[] a;
    D[] b;
    const(C)[] c;
    const(D)[] d;
    immutable(C)[] e;
    immutable(D)[] f;

    static assert( __traits(compiles, a = a));
    static assert(!__traits(compiles, a = b));
    static assert(!__traits(compiles, a = c));
    static assert(!__traits(compiles, a = d));
    static assert(!__traits(compiles, a = e));
    static assert(!__traits(compiles, a = f));

    static assert(!__traits(compiles, b = a));
    static assert( __traits(compiles, b = b));
    static assert(!__traits(compiles, b = c));
    static assert(!__traits(compiles, b = d));
    static assert(!__traits(compiles, b = e));
    static assert(!__traits(compiles, b = f));

    static assert( __traits(compiles, c = a));
    static assert( __traits(compiles, c = b));
    static assert( __traits(compiles, c = c));
    static assert( __traits(compiles, c = d));
    static assert( __traits(compiles, c = e));
    static assert( __traits(compiles, c = f));

    static assert(!__traits(compiles, d = a));
    static assert( __traits(compiles, d = b));
    static assert(!__traits(compiles, d = c));
    static assert( __traits(compiles, d = d));
    static assert(!__traits(compiles, d = e));
    static assert( __traits(compiles, d = f));

    static assert(!__traits(compiles, e = a));
    static assert(!__traits(compiles, e = b));
    static assert(!__traits(compiles, e = c));
    static assert(!__traits(compiles, e = d));
    static assert( __traits(compiles, e = e));
    static assert( __traits(compiles, e = f));

    static assert(!__traits(compiles, f = a));
    static assert(!__traits(compiles, f = b));
    static assert(!__traits(compiles, f = c));
    static assert(!__traits(compiles, f = d));
    static assert(!__traits(compiles, f = e));
    static assert( __traits(compiles, f = f));
}


void staticarrays()
{
    C[1] sa;
    D[1] sb;

    const(C)[1] sc = sa;
    const(D)[1] sd = sb;

    sa = sb;
    static assert(!__traits(compiles, sb = sa));
}

void main() {}
