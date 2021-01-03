// https://issues.dlang.org/show_bug.cgi?id=8006

/**************************************************************
* int tests
**************************************************************/
struct TInt
{
    int mX;

    @property int x() { return mX; }
    @property void x(int v) { mX = v; }

    alias x this;
}

// It was found, during the implementation of binary assignment operators
// for @property functions that if the setter was declared before the getter
// the binary assignment operator call would not compile.  This was due
// to the fact that if e.e1.copy() was called after resolveProperties(e.e1)
// that the copy() call would return the wrong overload for the @property
// function.  This is a test to guard against that.
struct TIntRev
{
    int mX;

    @property void x(int v) { mX = v; }
    @property int x() { return mX; }

    alias x this;
}

// Ensure that `ref @property` functions also *still* work
struct TIntRef
{
    int mX;

    @property ref int x() { return mX; }
    @property ref int x(int v) { return mX = v; }

    alias x this;
}

// same as above with no setter
struct TIntRefNoSetter
{
    int mX;

    @property ref int x() { return mX; }

    alias x this;
}

// Same as TInt, but setter @property function returns a value
struct TIntRet
{
    int mX;

    @property int x() { return mX; }
    @property int x(int v) { return mX = v; }

    alias x this;
}

// same as TInt, but with static @property functions
struct TIntStatic
{
    static int mX;

    static @property int x() { return mX; }
    static @property void x(int v) { mX = v; }

    alias x this;
}

// same as TIntStatic, but setter @property function returns a value
struct TIntRetStatic
{
    static int mX;

    static @property int x() { return mX; }
    static @property int x(int v) { return mX = v; }

    alias x this;
}

// This test verifies typical arithmetic and logical operators
void testTInt(T)()
{
    // modeled after code from runnable/testassign.d

    static if (typeid(T) is typeid(TInt))
    {
        TInt t;
    }
    else static if (typeid(T) is typeid(TIntRev))
    {
        TIntRev t;
    }
    else static if (typeid(T) is typeid(TIntRef))
    {
        TIntRef t;
    }
    else static if (typeid(T) is typeid(TIntRefNoSetter))
    {
        TIntRefNoSetter t;
    }
    else static if (typeid(T) is typeid(TIntStatic))
    {
        alias t = TIntStatic;
    }
    else
    {
        static assert(false, "Type is not supported");
    }

    t.x += 4;
    assert(t.mX == 4);
    t.x -= 2;
    assert(t.mX == 2);
    t.x *= 4;
    assert(t.mX == 8);
    t.x /= 2;
    assert(t.mX == 4);
    t.x %= 3;
    assert(t.mX == 1);
    t.x <<= 3;
    assert(t.mX == 8);
    t.x >>= 1;
    assert(t.mX == 4);
    t.x >>>= 1;
    assert(t.mX == 2);
    t.x &= 0xF;
    assert(t.mX == 0x2);
    t.x |= 0x8;
    assert(t.mX == 0xA);
    t.x ^= 0xF;
    assert(t.mX == 0x5);
    t.x ^^= 2;
    assert(t.mX == 25);

    // same as test above, but through the `alias this`
    t = 0;
    t += 4;
    assert(t.mX == 4);
    t -= 2;
    assert(t.mX == 2);
    t *= 4;
    assert(t.mX == 8);
    t /= 2;
    assert(t.mX == 4);
    t %= 3;
    assert(t.mX == 1);
    t <<= 3;
    assert(t.mX == 8);
    t >>= 1;
    assert(t.mX == 4);
    t >>>= 1;
    assert(t.mX == 2);
    t &= 0xF;
    assert(t.mX == 0x2);
    t |= 0x8;
    assert(t.mX == 0xA);
    t ^= 0xF;
    assert(t.mX == 0x5);
    t ^^= 2;
    assert(t.mX == 25);
}

// This test is to verify that the setter @property function
// returns a value if it is explicitly coded to do so
void testTIntRet(T)()
{
    static if (typeid(T) is typeid(TIntRet))
    {
        TIntRet t;
    }
    else static if (typeid(T) is typeid(TIntRetStatic))
    {
        alias t = TIntRetStatic;
    }
    else
    {
        static assert(false, "Type is not supported");
    }

    int r;
    r = t.x += 4;
    assert(r == 4);
    r = t.x -= 2;
    assert(r == 2);
    r = t.x *= 4;
    assert(r == 8);
    r = t.x /= 2;
    assert(r == 4);
    r = t.x %= 3;
    assert(r == 1);
    r = t.x <<= 3;
    assert(r == 8);
    r = t.x >>= 1;
    assert(r == 4);
    r = t.x >>>= 1;
    assert(r == 2);
    r = t.x &= 0xF;
    assert(r == 0x2);
    r = t.x |= 0x8;
    assert(r == 0xA);
    r = t.x ^= 0xF;
    assert(r == 0x5);
    r = t.x ^^= 2;
    assert(r == 25);

    // same as test above, but through the `alias this`
    t = 0;
    r = t += 4;
    assert(r == 4);
    r = t -= 2;
    assert(r == 2);
    r = t *= 4;
    assert(r == 8);
    r = t /= 2;
    assert(r == 4);
    r = t %= 3;
    assert(r == 1);
    r = t <<= 3;
    assert(r == 8);
    r = t >>= 1;
    assert(r == 4);
    r = t >>>= 1;
    assert(r == 2);
    r = t &= 0xF;
    assert(r == 0x2);
    r = t |= 0x8;
    assert(r == 0xA);
    r = t ^= 0xF;
    assert(r == 0x5);
    r = t ^^= 2;
    assert(r == 25);
}

/**************************************************************
* string/array tests
**************************************************************/
struct TString
{
    string mX;

    @property string x() { return mX; }
    @property void x(string v) { mX = v; }

    alias x this;
}

// same as TString, but setter @property function returns a value
struct TStringRet
{
    string mX;

    @property string x() { return mX; }
    @property string x(string v) { return mX = v; }

    alias x this;
}

struct TStringOp
{
    string mX;

    @property string x() { return mX; }
    @property void x(string v) { mX = v; }

    string mB;
    string opOpAssign(string op)(string rhs)
    {
        return mixin("mB "~op~"= rhs");
    }

    alias x this;
}

// same as TString, but for static @property functions
struct TStringStatic
{
    static string mX;

    static @property string x() { return mX; }
    static @property void x(string v) { mX = v; }

    static alias x this;
}

// same as TStringRet, but for static @property functions
struct TStringRetStatic
{
    static string mX;

    static @property string x() { return mX; }
    static @property string x(string v) { return mX = v; }

    static alias x this;
}

// Test string (i.e. array) operators
void testTString(T)()
{
    static if (typeid(T) is typeid(TString))
    {
        TString t;
    }
    else static if (typeid(T) is typeid(TStringStatic))
    {
        alias t = TStringStatic;
    }
    else
    {
        static assert(false, "Type is not supported");
    }

    t.x = "abc";
    t.x ~= "def";
    assert(t.mX == "abcdef");

    // same as test above, but through the `alias this`
    t = "abc";
    t ~= "def";
    assert(t.mX == "abcdef");
}

// This test is to verify that the setter @property function
// returns a value if it is explicitly coded to do so
void testTStringRet(T)()
{
    static if (typeid(T) is typeid(TStringRet))
    {
        TStringRet t;
    }
    else static if (typeid(T) is typeid(TStringRetStatic))
    {
        alias t = TStringRetStatic;
    }
    else
    {
        static assert(false, "Type is not supported");
    }

    string s;
    t.x = "abc";
    s = t.x ~= "def";
    assert(s == "abcdef");

    // same as test above, but through the `alias this`
    t = "abc";
    s = t ~= "def";
    assert(s == "abcdef");
}

/**************************************************************
* Free @property function test
**************************************************************/
int mX;
@property int x() { return mX; }
@property void x(int v) { mX = v; }

// Test that free @property functions work
void testFreeFunctionsInt()
{
    x += 4;
    assert(mX == 4);
    x -= 2;
    assert(mX == 2);
    x *= 4;
    assert(mX == 8);
    x /= 2;
    assert(mX == 4);
    x %= 3;
    assert(mX == 1);
    x <<= 3;
    assert(mX == 8);
    x >>= 1;
    assert(mX == 4);
    x >>>= 1;
    assert(mX == 2);
    x &= 0xF;
    assert(mX == 0x2);
    x |= 0x8;
    assert(mX == 0xA);
    x ^= 0xF;
    assert(mX == 0x5);
    x ^^= 2;
    assert(mX == 25);
}

int mXret;
@property int xret() { return mXret; }
@property int xret(int v) { return mXret = v; }

// Same as testFreeFunctions except that we want to
// ensure the binary assignment returns a value
void testFreeFunctionsIntRet()
{
    int r;
    r = xret += 4;
    assert(r == 4);
    r = xret -= 2;
    assert(r == 2);
    r = xret *= 4;
    assert(r == 8);
    r = xret /= 2;
    assert(r == 4);
    r = xret %= 3;
    assert(r == 1);
    r = xret <<= 3;
    assert(r == 8);
    r = xret >>= 1;
    assert(r == 4);
    r = xret >>>= 1;
    assert(r == 2);
    r = xret &= 0xF;
    assert(r == 0x2);
    r = xret |= 0x8;
    assert(r == 0xA);
    r = xret ^= 0xF;
    assert(r == 0x5);
    r = xret ^^= 2;
    assert(r == 25);
}

string mXs;
@property string xs() { return mXs; }
@property void xs(string v) { mXs = v; }

void testFreeFunctionsString()
{
    xs = "abc";
    xs ~= "def";
    assert(mXs == "abcdef");
}

string mXsret;
@property string xsret() { return mXsret; }
@property string xsret(string v) { return mXsret = v; }

void testFreeFunctionsStringRet()
{
    string s;
    xsret = "abc";
    s = xsret ~= "def";
    assert(s == "abcdef");
}

/**************************************************************
* Nested @property function test
**************************************************************/

// At the time of writing this test case, the compiler would not
// allow overloading nested functions.  So, it was impossible to
// create a getter/setter pair, but it wouldd allow a single ref
// @property getter, so I added that test.

// Test that nested @property functions work
void testNestedFunctionsIntRef()
{
    int mP;
    @property ref int p() { return mP; }

    p += 4;
    assert(mP == 4);
    p -= 2;
    assert(mP == 2);
    p *= 4;
    assert(mP == 8);
    p /= 2;
    assert(mP == 4);
    p %= 3;
    assert(mP == 1);
    p <<= 3;
    assert(mP == 8);
    p >>= 1;
    assert(mP == 4);
    p >>>= 1;
    assert(mP == 2);
    p &= 0xF;
    assert(mP == 0x2);
    p |= 0x8;
    assert(mP == 0xA);
    p ^= 0xF;
    assert(mP == 0x5);
    p ^^= 2;
    assert(mP == 25);
}

// Same as testNestedFunctionsIntRef except that we want to
// ensure the binary assignment returns a value
void testNestedFunctionsIntRefRet()
{
    int mP;
    @property ref int p() { return mP; }

    int r;
    r = p += 4;
    assert(r == 4);
    r = p -= 2;
    assert(r == 2);
    r = p *= 4;
    assert(r == 8);
    r = p /= 2;
    assert(r == 4);
    r = p %= 3;
    assert(r == 1);
    r = p <<= 3;
    assert(r == 8);
    r = p >>= 1;
    assert(r == 4);
    r = p >>>= 1;
    assert(r == 2);
    r = p &= 0xF;
    assert(r == 0x2);
    r = p |= 0x8;
    assert(r == 0xA);
    r = p ^= 0xF;
    assert(r == 0x5);
    r = p ^^= 2;
    assert(r == 25);
	r = p++;
	assert(r == 26);
	r = p--;
	assert(r == 25);
	++p;
	assert(p == 26);
	--p;
	assert(p == 25);
}

void testNestedFunctionsStringRef()
{
    string mP;
    @property ref string p() { return mP; }

    mP = "abc";
    p ~= "def";
    assert(mP == "abcdef");
}

// Same as testNestedFunctionsStringRef except that we want to
// ensure the binary assignment returns a value
void testNestedFunctionsStringRefRet()
{
    string mP;
    @property ref string p() { return mP; }

    string s;
    mP = "abc";
    s = p ~= "def";
    assert(s == "abcdef");
}

/**************************************************************
* This test is to ensure the that expression e1.prop @= e2 is
* rewritten in a way that does not evaluate e1 more than once
**************************************************************/
struct TSideEffectsInt
{
    int mX;
    @property int X() {return mX;}
    @property int X(int value) { return mX = value;}
}

TSideEffectsInt tSideEffectsInt;
int tSideEffectsIntCount = 0;

TSideEffectsInt* getTSideEffectsInt()
{
    tSideEffectsIntCount++;
    return &tSideEffectsInt;
}

void testSideEffectsInt()
{
    tSideEffectsInt.mX = 0;

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X += 4;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X -= 2;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X *= 4;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X /= 2;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X %= 3;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X <<= 3;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X >>= 1;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X >>>= 1;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X &= 0xF;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X |= 0x8;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X ^= 0xF;
    assert(tSideEffectsIntCount == 1);

    tSideEffectsIntCount = 0;
    getTSideEffectsInt().X ^^= 2;
    assert(tSideEffectsIntCount == 1);
}

// Same as testSideEffectsInt() only for string type
struct TSideEffectsString
{
    string mX;
    @property string X() {return mX;}
    @property string X(string value) { return mX = value;}
}

TSideEffectsString tSideEffectsString;
int tSideEffectsStringCount = 0;

TSideEffectsString* getTSideEffectsString()
{
    tSideEffectsStringCount++;
    return &tSideEffectsString;
}

void testSideEffectsString()
{
    tSideEffectsString.mX = "abc";

    tSideEffectsStringCount = 0;
    getTSideEffectsString().X ~= "def";
    assert(tSideEffectsStringCount == 1);
}

void main()
{
    testTInt!TInt();
    testTInt!TIntRev();
    testTInt!TIntRef();
    testTInt!TIntRefNoSetter();
    testTInt!TIntStatic();

    testTIntRet!TIntRet();
    testTIntRet!TIntRetStatic();

    testTString!TString();
    testTString!TStringStatic();

    testTStringRet!TStringRet();
    testTStringRet!TStringRetStatic();

    testFreeFunctionsInt();
    testFreeFunctionsIntRet();

    testFreeFunctionsString();
    testFreeFunctionsStringRet();

    testNestedFunctionsIntRef();
    testNestedFunctionsIntRefRet();

    testNestedFunctionsStringRef();
    testNestedFunctionsStringRefRet();

    testSideEffectsInt();

    testSideEffectsString();
}