/*
 * TEST_OUTPUT:
---
fail_compilation/test8006.d(79): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(80): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(81): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(82): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(83): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(84): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(85): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(86): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(87): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(88): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(89): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(90): Error: function `test8006.TInt.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(94): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(95): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(96): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(97): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(98): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(99): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(100): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(101): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(102): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(103): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(104): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(105): Error: `ti.y()` is not an lvalue
fail_compilation/test8006.d(124): Error: function `test8006.TString.x()` is not callable using argument types `(string)`
fail_compilation/test8006.d(128): Error: `ts.y()` is not an lvalue
fail_compilation/test8006.d(154): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(155): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(156): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(157): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(158): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(159): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(160): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(161): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(162): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(163): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(164): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(165): Error: function `test8006.x()` is not callable using argument types `(int)`
fail_compilation/test8006.d(167): Error: function `test8006.xs()` is not callable using argument types `(string)`
fail_compilation/test8006.d(171): Error: `y()` is not an lvalue
fail_compilation/test8006.d(172): Error: `y()` is not an lvalue
fail_compilation/test8006.d(173): Error: `y()` is not an lvalue
fail_compilation/test8006.d(174): Error: `y()` is not an lvalue
fail_compilation/test8006.d(175): Error: `y()` is not an lvalue
fail_compilation/test8006.d(176): Error: `y()` is not an lvalue
fail_compilation/test8006.d(177): Error: `y()` is not an lvalue
fail_compilation/test8006.d(178): Error: `y()` is not an lvalue
fail_compilation/test8006.d(179): Error: `y()` is not an lvalue
fail_compilation/test8006.d(180): Error: `y()` is not an lvalue
fail_compilation/test8006.d(181): Error: `y()` is not an lvalue
fail_compilation/test8006.d(182): Error: `y()` is not an lvalue
fail_compilation/test8006.d(184): Error: `ys()` is not an lvalue
---
 */

// https://issues.dlang.org/show_bug.cgi?id=8006

// modeled after code from runnable/testassign.d

struct TInt
{
    int mX;

    @property int x() { return mX; }

    int mY;
    int y() { return mY; }
    int y(int v) { return mY = v; }
}

void testTInt()
{
    // all of these should fail to compile because there is
    // no setter property
    TInt ti;
    ti.x += 4;
    ti.x -= 2;
    ti.x *= 4;
    ti.x /= 2;
    ti.x %= 3;
    ti.x <<= 3;
    ti.x >>= 1;
    ti.x >>>= 1;
    ti.x &= 0xF;
    ti.x |= 0x8;
    ti.x ^= 0xF;
    ti.x ^^= 2;

    // all of these should fail to compile because y is not a
    // @property function
    ti.y += 4;
    ti.y -= 2;
    ti.y *= 4;
    ti.y /= 2;
    ti.y %= 3;
    ti.y <<= 3;
    ti.y >>= 1;
    ti.y >>>= 1;
    ti.y &= 0xF;
    ti.y |= 0x8;
    ti.y ^= 0xF;
    ti.y ^^= 2;
}

struct TString
{
    string mX;

    @property string x() { return mX; }

    string mY;
    string y() { return mY; }
    string y(string v) { return mY = v; }
}

void testTString()
{
    // this should fail to compile because there is
    // no setter property
    TString ts;
    ts.x ~= "def";

    // this should fail to compile because y is not a
    // @property function
    ts.y ~= "def";
}


// int @property function without a setter
int mX;
@property int x() { return mX; }

// int non-@property functions
int mY;
int y() { return mY; }
int y(int v) { return mY = v; }

// string @property function without a setter
string mXs;
@property string xs() { return mXs; }

// string non-@property functions
string mYs;
string ys() { return mYs; }
string ys(string v) { return mYs = v; }

void testFreeFunctions()
{
    // all of these should fail to compile because there is
    // no setter property
    x += 4;
    x -= 2;
    x *= 4;
    x /= 2;
    x %= 3;
    x <<= 3;
    x >>= 1;
    x >>>= 1;
    x &= 0xF;
    x |= 0x8;
    x ^= 0xF;
    x ^^= 2;

    xs ~= "def";

    // all of these should fail to compile because y and ys are not
    // @property function
    y += 4;
    y -= 2;
    y *= 4;
    y /= 2;
    y %= 3;
    y <<= 3;
    y >>= 1;
    y >>>= 1;
    y &= 0xF;
    y |= 0x8;
    y ^= 0xF;
    y ^^= 2;

    ys ~= "def";
}

void main()
{
    testTInt();
    testTString();
    testFreeFunctions();
}