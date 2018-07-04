// REQUIRED_ARGS: -vnrvo

import core.stdc.stdio;

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=5777

/* TEST_OUTPUT:
---
testnrv.d(25): function `makeS5777` returns using named return value optimization
---
*/

int sdtor5777 = 0;

struct S5777
{
    @disable this(this);
    ~this(){ ++sdtor5777; }
}

S5777 makeS5777()
{
    S5777 s;
    return s;
}

void test5777()
{
    auto s1 = makeS5777();
    assert(sdtor5777 == 0);
}

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=9985

/* TEST_OUTPUT:
---
testnrv.d(54): function `makeS9985` returns using named return value optimization
---
*/

struct S9985
{
    ubyte* b;
    ubyte[128] buf;
    this(this) { assert(0); }
}

auto ref makeS9985() @system
{
    S9985 s;
    s.b = s.buf.ptr;
    return s;
}

void test9985()
{
    S9985 s = makeS9985();      // NRVO
}

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=10094

/* TEST_OUTPUT:
---
testnrv.d(82): function `__lambda1` returns using named return value optimization
---
*/

void test10094()
{
    const string[4] i2s = ()
    {
        string[4] tmp;
        for (int i = 0; i < 4; ++i)
        {
            char[1] buf = [cast(char)('0' + i)];
            string str = buf.idup;
            tmp[i] = str;
        }
        return tmp; // NRVO should work
    }();
    assert(i2s == ["0", "1", "2", "3"]);
}

/************************************/
// https://issues.dlang.org/show_bug.cgi?id=11224

/* TEST_OUTPUT:
---
testnrv.d(116): function `foo11224` returns using named return value optimization
---
*/

S11224* ptr11224;

struct S11224
{
    this(int)
    {
        ptr11224 = &this;
        /*printf("ctor &this = %p\n", &this);*/
    }
    this(this)
    {
        /*printf("cpctor &this = %p\n", &this);*/
    }
    int num;
}
S11224 foo11224()
{
    S11224 s = S11224(1);
    //printf("foo  &this = %p\n", &s);
    assert(ptr11224 is &s);
    return s;
}
void test11224()
{
    auto s = foo11224();
    //printf("main &this = %p\n", &s);
}

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=11394

/* TEST_OUTPUT:
---
testnrv.d(141): function `make11394` returns using named return value optimization
---
*/

static int[5] make11394(in int x) pure
{
    typeof(return) a;
    a[0] = x;
    a[1] = x + 1;
    a[2] = x + 2;
    a[3] = x + 3;
    a[4] = x + 4;
    return a;
}

struct Bar11394
{
    immutable int[5] arr;

    this(int x)
    {
        this.arr = make11394(x);    // NRVO should work
    }
}

void test11394()
{
    auto b = Bar11394(5);
}

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=12045

/* TEST_OUTPUT:
---
testnrv.d(188): function `makeS12045` returns using named return value optimization
---
*/

bool test12045()
{
    string dtor;

    struct S12045
    {
        string val;

        this(this) { assert(0); }
        ~this() { dtor ~= val; }
    }

    auto makeS12045(bool thrown)
    {
        auto s1 = S12045("1");
        auto s2 = S12045("2");

        if (thrown)
            throw new Exception("");

        return s1;  // NRVO
    }

    dtor = null;
    try
    {
        S12045 s = makeS12045(true);
        assert(0);
    }
    catch (Exception e)
    {
        assert(dtor == "21", dtor);
    }

    dtor = null;
    {
        S12045 s = makeS12045(false);
        assert(dtor == "2");
    }
    assert(dtor == "21");

    return true;
}
static assert(test12045());

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=13089

/* TEST_OUTPUT:
---
testnrv.d(231): function `foo13089` returns using named return value optimization
---
*/

struct S13089
{
    @disable this(this);    // non nothrow
    int val;
}

S13089[1000] foo13089() nothrow
{
    typeof(return) data;
    return data;
}

void test13089() nothrow
{
    immutable data = foo13089();
}

/**********************************/
// https://issues.dlang.org/show_bug.cgi?id=17457

/* TEST_OUTPUT:
---
testnrv.d(257): function `foo17457` returns using named return value optimization
---
*/

struct S17457 {
    ulong[10] data;

    this(int seconds) {}
    void mfunc() {}
}

auto foo17457() {
    pragma(inline, false);
    return S17457(18);
}

void test17457()
{
    auto x = foo17457();    // NRVO
}

/**********************************/

int main()
{
    test5777();
    test9985();
    test10094();
    test11224();
    test11394();
    test12045();
    test13089();
    test17457();

    printf("Success\n");
    return 0;
}
