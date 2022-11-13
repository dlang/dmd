@safe pure:

class X
{
    this(int x) @safe pure { this.x = x; }
    int x;
}

class Y : X
{
    this(int x) @safe pure { super(x); }
    int x;
}

static void fm(X[] xs) {}
static void fc(const(X)[] xs) {}
static void fi(immutable(X)[] xs) {}

static void f2m(X[2] xs) {}
static void f2mr(ref X[2] xs) {}

void test()
{
    Y[] y = [new Y(42), new Y(43)];
    immutable(Y)[] yi = [new Y(42), new Y(43)];
    static assert(!__traits(compiles, { fm(y); }));
    fc(y);
    fc(yi);
    fi(yi);

    Y[2] y2 = [new Y(42), new Y(43)];
    f2m(y2);
    static assert(!__traits(compiles, { f2mr(y2); }));
}
