// Consolidated tests for the `^^` (pow) operator.
//
// `^^` lowers to `object._d_pow`, which still imports `std.math` internally
// (see the TODO in druntime's object.d), so Phobos is needed on the link line
// until that hook is moved into druntime.
// RUNNABLE_PHOBOS_TEST
// PERMUTE_ARGS:

// runtime `^^` with a runtime exponent

__gshared uint x0 = 0;
__gshared uint x1 = 1;
__gshared uint x2 = 2;
__gshared uint x3 = 3;
__gshared uint x4 = 4;
__gshared uint x5 = 5;
__gshared uint x6 = 6;
__gshared uint x7 = 7;
__gshared uint x10 = 10;
__gshared uint x15 = 15;
__gshared uint x31 = 31;
__gshared uint x32 = 32;

void test5943()
{
    assert(2 ^^ x0 == 1);
    assert(2 ^^ x1 == 2);
    assert(2 ^^ x31 == 0x80000000);
    assert(4 ^^ x0 == 1);
    assert(4 ^^ x1 == 4);
    assert(4 ^^ x15 == 0x40000000);
    assert(8 ^^ x0 == 1);
    assert(8 ^^ x1 == 8);
    assert(8 ^^ x10 == 0x40000000);
    assert(16 ^^ x0 == 1);
    assert(16 ^^ x1 == 16);
    assert(16 ^^ x7 == 0x10000000);
    assert(32 ^^ x0 == 1);
    assert(32 ^^ x1 == 32);
    assert(32 ^^ x6 == 0x40000000);
    assert(64 ^^ x0 == 1);
    assert(64 ^^ x1 == 64);
    assert(64 ^^ x5 == 0x40000000);
    assert(128 ^^ x0 == 1);
    assert(128 ^^ x1 == 128);
    assert(128 ^^ x4 == 0x10000000);
    assert(256 ^^ x0 == 1);
    assert(256 ^^ x1 == 256);
    assert(256 ^^ x3 == 0x1000000);
    assert(512 ^^ x0 == 1);
    assert(512 ^^ x1 == 512);
    assert(512 ^^ x3 == 0x8000000);
    assert(1024 ^^ x0 == 1);
    assert(1024 ^^ x1 == 1024);
    assert(1024 ^^ x3 == 0x40000000);
    assert(2048 ^^ x0 == 1);
    assert(2048 ^^ x1 == 2048);
    assert(2048 ^^ x2 == 0x400000);
    assert(4096 ^^ x0 == 1);
    assert(4096 ^^ x1 == 4096);
    assert(4096 ^^ x2 == 0x1000000);
    assert(8192 ^^ x0 == 1);
    assert(8192 ^^ x1 == 8192);
    assert(8192 ^^ x2 == 0x4000000);
    assert(16384 ^^ x0 == 1);
    assert(16384 ^^ x1 == 16384);
    assert(16384 ^^ x2 == 0x10000000);
    assert(32768 ^^ x0 == 1);
    assert(32768 ^^ x1 == 32768);
    assert(32768 ^^ x2 == 0x40000000);
    assert(65536 ^^ x0 == 1);
    assert(65536 ^^ x1 == 65536);
    assert(131072 ^^ x0 == 1);
    assert(131072 ^^ x1 == 131072);
    assert(262144 ^^ x0 == 1);
    assert(262144 ^^ x1 == 262144);
    assert(524288 ^^ x0 == 1);
    assert(524288 ^^ x1 == 524288);
    assert(1048576 ^^ x0 == 1);
    assert(1048576 ^^ x1 == 1048576);
    assert(2097152 ^^ x0 == 1);
    assert(2097152 ^^ x1 == 2097152);
    assert(4194304 ^^ x0 == 1);
    assert(4194304 ^^ x1 == 4194304);
}

// https://issues.dlang.org/show_bug.cgi?id=11159

void test11159()
{
    import std.math : pow;
    enum ulong
        e_2_pow_64 = 2uL^^64,
        e_10_pow_19 = 10uL^^19,
        e_10_pow_20 = 10uL^^20;
    assert(e_2_pow_64 == pow(2uL, 64));
    assert(e_10_pow_19 == pow(10uL, 19));
    assert(e_10_pow_20 == pow(10uL, 20));
}

// CTFE / typing rules for `^^`
// Test float ^^ int
static assert( 27.0 ^^ 5 == 27.0 * 27.0 * 27.0 * 27.0 * 27.0);
static assert( 2.0 ^^ 3 == 8.0);

static assert( 2.0 ^^ 4 == 16.0);
static assert( 2 ^^ 4 == 16);

static assert((2 ^^ 8) == 256);
static assert((3 ^^ 8.0) == 6561);
static assert((4.0 ^^ 8) == 65536);
static assert((5.0 ^^ 8.0) == 390625);

static assert((0.5 ^^ 3) == 0.125);
static assert((1.5 ^^ 3.0) == 3.375);
static assert((2.5 ^^ 3) == 15.625);
static assert((3.5 ^^ 3.0) == 42.875);

static assert(((-2) ^^ -5.0) == -0.031250);
static assert(((-2.0) ^^ -6) == 0.015625);
static assert(((-2.0) ^^ -7.0) == -0.0078125);

static assert((144 ^^ 0.5) == 12);
static assert((1089 ^^ 0.5) == 33);
static assert((1764 ^^ 0.5) == 42);
static assert((650.25 ^^ 0.5) == 25.5);

// Check the typing rules.
static assert( is (typeof(2.0^^7) == double));
static assert( is (typeof(7^^3) == int));

static assert( is (typeof(7L^^3) == long));
static assert( is (typeof(7^^3L) == long));
enum short POW_SHORT_1 = 3;
enum short POW_SHORT_3 = 7;
static assert( is (typeof(POW_SHORT_1 * POW_SHORT_1) ==
typeof(POW_SHORT_1*POW_SHORT_1)));

static assert( is (typeof(7.0^^3) == double));
static assert( is (typeof(7.0L^^3) == real));
static assert( is (typeof(7.0f^^3) == float));
static assert( is (typeof(POW_SHORT_1^^3.1) == double));
static assert( is (typeof(POW_SHORT_1^^3.1f) == float));
static assert( is (typeof(2.1f ^^ POW_SHORT_1) == float));
static assert( is (typeof(7.0f^^3.1) == double));
static assert( is (typeof(7.0^^3.1f) == double));
static assert( is (typeof(7.0f^^3.1f) == float));
static assert( is (typeof(7.0f^^3.1L) == real));
static assert( is (typeof(7.0L^^3.1f) == real));
// Check typing for special cases
static assert( is (typeof(7.0f^^2) == float));
static assert( is (typeof(7.0f^^2.0) == double));
static assert( is (typeof(7.0f^^8.0) == double));
static assert( is (typeof(1^^0.5f) == float));
static assert( is (typeof(7^^0.5f) == float));
static assert( is (typeof(3L^^0.5) == double));
static assert( is (typeof(123^^17.0f) == float));

static assert(POW_SHORT_1 ^^ 2 == 9);
static assert(4.0 ^^ POW_SHORT_1 == 4.0*4.0*4.0);
static assert(4.0 ^^ 7.0 == 4.0*4.0*4.0*4.0*4.0*4.0*4.0);

// ^^ has higher precedence than multiply
static assert( 2 * 2 ^^ 3 + 1 == 17);
static assert( 2 ^^ 3 * 2 + 1 == 17);
// ^^ has higher precedence than negate
static assert( -2 ^^ 3 * 2 - 1 == -17);

// ^^ is right associative
static assert( 2 ^^ 3 ^^ 2 == 2 ^^ 9);
static assert( 2.0 ^^ -3 ^^ 2 == 2.0 ^^ -9);

// 1 ^^ n is always 1, even if n is negative
static assert( 1 ^^ -5.0 == 1);

// -1.0 ^^ n is either 1 or -1 if n is integral.
static assert( (-1.0) ^^ -5 == -1);
static assert( (-1.0) ^^ -4 == 1);
static assert( (-1.0) ^^ 0 == 1);
// -1.0 ^^ n is otherwise always NaN.
static assert( (-1.0) ^^ -5.5 is double.nan);
static assert( (-1.0) ^^ -4.4 is double.nan);
static assert( (-1.0) ^^ -0.1 is double.nan);

// n ^^ 0 is always 1
static assert( (-5) ^^ 0 == 1);

// n ^^ 1 is always n
static assert( 6.0 ^^ 1 == 6.0);

// n ^^ -1.0 gets transformed into 1.0 / n, even if n is negative
static assert( (-4) ^^ -1.0 == 1.0 / -4);
static assert( 9 ^^ -1.0 == 1.0 / 9);

// Other integers raised to negative powers create an error
static assert( !is(typeof(2 ^^ -5)));
static assert( !is(typeof((-2) ^^ -4)));

// https://issues.dlang.org/show_bug.cgi?id=3535
struct StructWithCtor
{
    this(int _n) {
        n = _n; x = 5;
    }
    this(int _n, float _x) {
        n = _n; x = _x;
    }
    int n;
    float x;
}

int containsAsm()
{
    version (D_InlineAsm_X86)
        asm { nop; }
    else version (D_InlineAsm_X86_64)
        asm { nop; }
    return 0;
}

int bazra(int x)
{
   StructWithCtor p = StructWithCtor(4);
   return p.n ^^ 3;

}

static assert(bazra(14)==64);

void moreCommaTests()
{
   (containsAsm(), containsAsm());
   auto k = containsAsm();
   for (int i=0; i< k^^2; i+=StructWithCtor(1).n) {}
}

static int nastyForCtfe=4;

// Can't use a global variable
static assert(!is(typeof( (){ static assert(0!=nastyForCtfe^^2); })));

int anotherPowTest()
{
   double x = 5.0;
   return x^^4 > 2.0 ? 3: 2;
}

// https://github.com/dlang/dmd/issues/19075
// ^^= must compile for small integer types
void test19075()
{
    byte bw = 10;
    bw ^^= 3;
    assert(bw == cast(byte) 1000);

    ubyte ubw = 10;
    ubw ^^= 3;
    assert(ubw == cast(ubyte) 1000);

    short sw = 100;
    sw ^^= 3;
    assert(sw == cast(short) 1_000_000);

    ushort usw = 100;
    usw ^^= 3;
    assert(usw == cast(ushort) 1_000_000);
}

/************************************/
// https://issues.dlang.org/show_bug.cgi?id=3841
// `^^=` must compile for the type combinations below

void powAssign(LHS, RHS)()
{
    LHS a;
    RHS b;
    a ^^= b;
}

void testPowAssign()
{
    powAssign!(int, int)();
    powAssign!(long, int)();
    powAssign!(long, short)();
    powAssign!(float, long)();
    powAssign!(double, float)();
    powAssign!(float, double)();
}

// https://issues.dlang.org/show_bug.cgi?id=4465
void bug4465()
{
    const a = 2 ^^ 2;
    int b = a;
}

// https://issues.dlang.org/show_bug.cgi?id=6228
void test6228()
{
    int val;
    const(int)* ptr = &val;
    const(int)  temp;
    auto x = (*ptr) ^^ temp;
}

// https://issues.dlang.org/show_bug.cgi?id=10682
void text10682()
{
    ulong x = 1;
    ulong y = 2 ^^ x;
}

// https://issues.dlang.org/show_bug.cgi?id=14166
struct S14166
{
    int x;
    double y;
}
S14166 s14166;

static assert(is(typeof(s14166.x ^^ 2) == int));
static assert(is(typeof(s14166.y ^^= 2.5) == double));

/************************************/

void main()
{
    test5943();
    test11159();
    test19075();
    testPowAssign();
    moreCommaTests();
    bug4465();
    test6228();
    text10682();
}
