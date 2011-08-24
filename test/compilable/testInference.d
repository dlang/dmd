
// 6265.

pure nothrow @safe int h6265() {
    return 1;
}
int f6265a(alias g)() {
    return g();
}
pure nothrow @safe int i6265a() {
    return f6265a!h6265();
}

int f6265b()() {
    return h6265();
}
pure nothrow @safe int i6265b() {
    return f6265b();
}

pure nothrow @safe int i6265c() {
    return {
        return h6265();
    }();
}

// Make sure a function is not infered as pure if it isn't.

int fNPa() {
    return 1;
}
int gNPa()() {
    return fNPa();
}
static assert( __traits(compiles, function int ()         { return gNPa(); }));
static assert(!__traits(compiles, function int () pure    { return gNPa(); }));
static assert(!__traits(compiles, function int () nothrow { return gNPa(); }));
static assert(!__traits(compiles, function int () @safe   { return gNPa(); }));

// Need to ensure the comment in Expression::checkPurity is not violated.

void fECPa() {
    void g()() {
        void h() {
        }
        h();
    }
    static assert( is(typeof(&g!()) == void delegate() pure));
    static assert(!is(typeof(&g!()) == void delegate()));
}

void fECPb() {
    void g()() {
        void h() {
        }
        fECPb();
    }
    static assert(!is(typeof(&g!()) == void delegate() pure));
    static assert( is(typeof(&g!()) == void delegate()));
}

// 5936

auto bug5936c(R)(R i) @safe pure nothrow {
    return true;
}
static assert( bug5936c(0) );

// 6351

void bug6351(alias dg)()
{
    dg();
}

void test6351()
{
    void delegate(int[] a...) deleg6351 = (int[] a...){};
    alias bug6351!(deleg6351) baz6531;
}

// Add more tests regarding inferences later.

