import core.stdc.stdio;

enum real er1 = real.nan;
enum real er2 = 1;
static assert(er1 != er2);
static assert(!(er1 == er2));
static assert(!(er1 < er2));
static assert(!(er1 > er2));
static assert(!(er1 >= er2));
static assert(!(er1 <= er2));

enum double ed1 = real.nan;
enum double ed2 = 1;
static assert(ed1 != ed2);
static assert(!(ed1 == ed2));
static assert(!(ed1 < ed2));
static assert(!(ed1 > ed2));
static assert(!(ed1 >= ed2));
static assert(!(ed1 <= ed2));

bool b;


T byCTFE(T)()
{
    T x;
    return x;
}

void printNaN(T)(T x)
{
    ubyte[] px = cast(ubyte[])((&x)[0..1]);

    printf(T.stringof.ptr);
    printf(".nan = 0x");
    foreach_reverse(p; 0..T.sizeof)
        printf("%02x", px[p]);
    printf(" mantissa=%d\n", T.mant_dig);
}

bool bittst(ubyte[] ba, uint pos)
{
    uint mask = 1 << (pos % 8);
    version(LittleEndian)
        return (ba[pos / 8] & mask) != 0;
    else
        return (ba[$ - 1 - pos / 8] & mask) != 0;
}

void test2(T)()
{
    T a = T.init, b = T.nan;
    //printNaN(a);
    ubyte[] pa = cast(ubyte[])((&a)[0..1]);
    ubyte[] pb = cast(ubyte[])((&b)[0..1]);
    assert(pa[] == pb[]);

    enum c = byCTFE!T();
    a = c;
    assert(pa[] == pb[]);

    // the highest 2 bits of the mantissa should be set, everythng else zero
    assert(bittst(pa, T.mant_dig - 1));
    assert(bittst(pa, T.mant_dig - 2));
    foreach(p; 0..T.mant_dig - 2)
        assert(!bittst(pa, p));
}

bool test()
{
        real r1 = real.nan;
        real r2 = 1;
        b = (r1 != r2); assert(b);
        b = (r1 == r2); assert(!b);
        b = (r1 <  r2); assert(!b);
        b = (r1 >  r2); assert(!b);
        b = (r1 <= r2); assert(!b);
        b = (r1 >= r2); assert(!b);

        double d1 = double.nan;
        double d2 = 1;
        b = (d1 != d2); assert(b);
        b = (d1 == d2); assert(!b);
        b = (d1 <  d2); assert(!b);
        b = (d1 >  d2); assert(!b);
        b = (d1 <= d2); assert(!b);
        b = (d1 >= d2); assert(!b);

        float f1 = float.nan;
        float f2 = 1;
        b = (f1 != f2); assert(b);
        b = (f1 == f2); assert(!b);
        b = (f1 <  f2); assert(!b);
        b = (f1 >  f2); assert(!b);
        b = (f1 <= f2); assert(!b);
        b = (f1 >= f2); assert(!b);
        return true;
}

void main()
{
    assert(test());
    test2!float();
    test2!double();
    test2!real();
}
