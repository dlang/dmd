
static assert(2.0  * 3.0  ==  6 );
static assert(2.0  * 3.0i ==  6i);
static assert(2.0i * 3.0  ==  6i);
static assert(2.0i * 3.0i == -6 );

static assert(2.0  * (4.0 + 3.0i) ==  8  + 6i);
static assert(2.0i * (4.0 + 3.0i) ==  8i - 6 );
static assert((4.0 + 3.0i) * 2.0  ==  8  + 6i);
static assert((4.0 + 3.0i) * 2.0i ==  8i - 6 );
static assert((4.0 + 3.0i) * (5 + 7i) ==  -1 + 43i );

static assert((2.0).re == 2);
static assert((2.0i).re == 0);
static assert((3+2.0i).re == 3);

static assert((4.0i).im == 4);
static assert((2.0i).im == 2);
static assert((3+2.0i).im == 2);

static assert(6.0 / 2.0 == 3);
static assert(6i / 2i ==  3);
static assert(6  / 2i == -3i);
static assert(6i / 2  ==  3i);

static assert((6 + 4i) / 2 == 3 + 2i);
static assert((6 + 4i) / 2i == -3i + 2);

//static assert(2 / (6 + 4i) == -3i);
//static assert(2i / (6 + 4i)  ==  3i);
//static assert((1 + 2i) / (6 + 4i)  ==  3i);

static assert(6.0 % 2.0 == 0);
static assert(6.0 % 3.0 == 0);
static assert(6.0 % 4.0 == 2);

static assert(6.0i % 2.0i == 0);
static assert(6.0i % 3.0i == 0);
static assert(6.0i % 4.0i == 2i);


void checkconstref()
{
    void pfun(immutable(char)[]* a) {}
    void rfun(ref immutable(char)[] a) {}

    immutable char[] buf = "hello";
    static assert(!__traits(compiles, rfun(buf)));
    static assert(!__traits(compiles, pfun(buf)));

    immutable char[5] buf2 = "hello";
    static assert(!__traits(compiles, rfun(buf2)));
    static assert(!__traits(compiles, pfun(buf2)));

    void pcfun(const(char)[]* a) {}
    void rcfun(ref const(char)[] a) {}

    static assert(!__traits(compiles, rcfun(buf)));
    static assert(!__traits(compiles, pcfun(buf)));
    static assert(!__traits(compiles, rcfun(buf2)));
    static assert(!__traits(compiles, pcfun(buf2)));

    const char[] buf3 = "hello";
    const char[5] buf4 = "hello";

    static assert(!__traits(compiles, rcfun(buf3)));
    static assert(!__traits(compiles, pcfun(buf3)));
    static assert(!__traits(compiles, rcfun(buf4)));
    static assert(!__traits(compiles, pcfun(buf4)));
}

void classconv()
{
    class C {}

    static assert(!__traits(compiles, {
        C[] a = [new C()];
        const(C)[]* b = &a;
        *b = [new immutable(C)()];
    }));
}

void ptrconv()
{
    static assert(!__traits(compiles, {
        int** g = [new int].ptr;
        const(int*)** h = &g;
        *h = [new immutable(int)].ptr;
    }));
    static assert(!__traits(compiles, {
        int** g = [new int].ptr;
        const(int**)* h = &g;
        *h = [new immutable(int)].ptr;
    }));
}


void arrayconv()
{
    static assert(!__traits(compiles, {
        int[][] a = [[1]];
        const(int[][])[] b = [a];
        *b = [[1].idup];
    }));
}


void test70()
{
    digestToString70("1234567890123456");
}

void digestToString70(const char[16] digest)
{
    assert(digest[0] == '1');
    assert(digest[15] == '6');
}

void messwith(T)(const(T)[]* ts, const(T) t) {
    *ts ~= t;
}
void messwith(T)(ref const(T)[] ts, const(T) t) {
    ts ~= t;
}

class C {
    int x;
    this(int i) { x = i; }
}

void mainy(string[] args) {

    C[] cs;
    immutable C ci = new immutable(C)(6);

    assert (ci.x == 6);

    static assert(!__traits(compiles, messwith(&cs,ci)));
    static assert(!__traits(compiles, messwith(cs,ci)));

    cs[$-1].x = 14;

    assert (ci.x == 14); //whoops.
}

void main() {}

void sharedconv()
{
    shared(int)* a;
    shared(int*) b = a;
    a = b;

    inout(int)* c;
    inout(int*) d = c;
}

void ptrconv2()
{
    int*** a;
    const(int*)** b;
    const(int**)* c;
    const(int***) d;

    static assert( __traits(compiles, a = a));
    static assert(!__traits(compiles, a = b));
    static assert(!__traits(compiles, a = c));
    static assert(!__traits(compiles, a = d));

    static assert(!__traits(compiles, b = a));
    static assert( __traits(compiles, b = b));
    static assert(!__traits(compiles, b = c));
    static assert(!__traits(compiles, b = d));

    static assert( __traits(compiles, c = a));
    static assert( __traits(compiles, c = b));
    static assert( __traits(compiles, c = c));
    static assert( __traits(compiles, c = d));

    static assert( __traits(compiles, { const(int***) dx = a; } ));
    static assert( __traits(compiles, { const(int***) dx = b; } ));
    static assert( __traits(compiles, { const(int***) dx = c; } ));
    static assert( __traits(compiles, { const(int***) dx = d; } ));
}
