// REQUIRED_ARGS: -d

// Test cases using deprecated features
module deprecate1;

import core.stdc.stdio : printf;
import std.traits;
import std.math : isNaN;


/**************************************
            volatile
**************************************/
void test5a(int *j)
{
    int i;

    volatile i = *j;
    volatile i = *j;
}

void test5()
{
    int x;

    test5a(&x);
}

// from test23
static int i2 = 1;

void test2()
{
    volatile { int i2 = 2; }
    assert(i2 == 1);
}

// bug 1200. Other tests in test42.d
void foo6e() {
        volatile debug {}
}


/**************************************
        octal literals
**************************************/

void test10()
{
    int b = 0b_1_1__1_0_0_0_1_0_1_0_1_0_;
    assert(b == 3626);

    b = 0_1_2_3_4_;
    printf("b = %d\n", b);
    assert(b == 668);
}

/**************************************
        backslash literals
**************************************/

// from lexer.d
void lexerTest7()
{
    auto str = \xDB;
    assert(str.length == 1);
}

/**************************************
            typedef
**************************************/

template func19( T )
{
    typedef T function () fp = &erf;
    T erf()
    {
	printf("erf()\n");
	return T.init;
    }
}

alias func19!( int ) F19;

F19.fp tc;

void test19()
{
    printf("tc = %p\n", tc);
    assert(tc() == 0);
}


/**************************************/

// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/578.html

typedef void* T60;

class A60
{
     int  List[T60][int][uint];

     void GetMsgHandler(T60 h,uint Msg)
     {
         assert(Msg in List[h][0]);    //Offending line
     }
}

void test60()
{
}

/**************************************/
// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/576.html

typedef ulong[3] BBB59;

template A59()
{
    void foo(BBB59 a)
    {
	printf("A.foo\n");
	bar(a);
    }
}

struct B59
{
    mixin A59!();

    void bar(BBB59 a)
    {
	printf("B.bar\n");
    }
}

void test59()
{
    ulong[3] aa;
    BBB59 a;
    B59 b;

    b.foo(a);
}

/***************************************/
// From variadic.d

template foo33(TA...)
{
  const TA[0] foo33=0;
}

template bar33(TA...)
{
  const TA[0..1][0] bar33=TA[0..1][0].init;
}

void test33()
{
    typedef int dummy33=0;
    typedef int myint=3;

    assert(foo33!(int)==0);
    assert(bar33!(int)==int.init);
    assert(bar33!(myint)==myint.init);
    assert(foo33!(int,dummy33)==0);
    assert(bar33!(int,dummy33)==int.init);
    assert(bar33!(myint,dummy33)==myint.init);
}

/***************************************/
// Bug 875  ICE(glue.c)

void test41()
{
    double bongos(int flux, string soup)
    {
        return 0.0;
    }

    auto foo = mk_future(& bongos, 99, "soup"[]);
}

int mk_future(A, B...)(A cmd, B args)
{
    typedef ReturnType!(A) TReturn;
    typedef ParameterTypeTuple!(A) TParams;
    typedef B TArgs;

    alias Foo41!(TReturn, TParams, TArgs) TFoo;

    return 0;
}

class Foo41(A, B, C) {
    this(A delegate(B), C)
    {
    }
}

// Typedef tests from test4.d
/* ================================ */

void test4_test26()
{
    typedef int foo = cast(foo)3;
    foo x;
    assert(x == cast(foo)3);

    typedef int bar = 4;
    bar y;
    assert(y == cast(bar)4);
}

/* ================================ */

struct Foo28
{
    int a;
    int b = 7;
}

void test4_test28()
{
  version (all)
  {
    int a;
    int b = 1;
    typedef int t = 2;
    t c;
    t d = cast(t)3;

    assert(int.init == 0);
    assert(a.init == 0);
    assert(b.init == 0);
    assert(t.init == cast(t)2);
    assert(c.init == cast(t)2);
    printf("d.init = %d\n", d.init);
    assert(d.init == cast(t)2);

    assert(Foo28.a.init == 0);
    assert(Foo28.b.init == 0);
  }
  else
  {
    int a;
    int b = 1;
    typedef int t = 2;
    t c;
    t d = cast(t)3;

    assert(int.init == 0);
    assert(a.init == 0);
    assert(b.init == 1);
    assert(t.init == cast(t)2);
    assert(c.init == cast(t)2);
    printf("d.init = %d\n", d.init);
    assert(d.init == cast(t)3);

    assert(Foo28.a.init == 0);
    assert(Foo28.b.init == 7);
  }
}

// from template4.d test 4
void template4_test4()
{
    typedef char Typedef;

    static if (is(Typedef Char == typedef))
    {
        static if (is(Char == char))
        { }
        else static assert(0);
    }
    else static assert(0);
}

// from structlit
typedef int myint10 = 4;

struct S10
{
    int i;
    union
    {	int x = 2;
	int y;
    }
    int j = 3;
    myint10 k;
}

void structlit_test10()
{
    S10 s = S10( 1 );
    assert(s.i == 1);
    assert(s.x == 2);
    assert(s.y == 2);
    assert(s.j == 3);
    assert(s.k == 4);

    static S10 t = S10( 1 );
    assert(t.i == 1);
    assert(t.x == 2);
    assert(t.y == 2);
    assert(t.j == 3);
    assert(t.k == 4);

    S10 u = S10( 1, 5 );
    assert(u.i == 1);
    assert(u.x == 5);
    assert(u.y == 5);
    assert(u.j == 3);
    assert(u.k == 4);

    static S10 v = S10( 1, 6 );
    assert(v.i == 1);
    assert(v.x == 6);
    assert(v.y == 6);
    assert(v.j == 3);
    assert(v.k == 4);
}

/******************************************/

void test15_test1()
{
    int i;
    bool[] b = new bool[10];
    for (i = 0; i < 10; i++)
	assert(b[i] == false);

    typedef bool tbit = true;
    tbit[] tb = new tbit[63];
    for (i = 0; i < 63; i++)
	assert(tb[i] == true);
}

void test15_test2()
{
    int i;
    byte[] b = new byte[10];
    for (i = 0; i < 10; i++)
    {	//printf("b[%d] = %d\n", i, b[i]);
	assert(b[i] == 0);
    }

    typedef byte tbyte = 0x23;
    tbyte[] tb = new tbyte[63];
    for (i = 0; i < 63; i++)
	assert(tb[i] == 0x23);
}


void test15_test3()
{
    int i;
    ushort[] b = new ushort[10];
    for (i = 0; i < 10; i++)
    {	//printf("b[%d] = %d\n", i, b[i]);
	assert(b[i] == 0);
    }

    typedef ushort tushort = 0x2345;
    tushort[] tb = new tushort[63];
    for (i = 0; i < 63; i++)
	assert(tb[i] == 0x2345);
}


void test15_test4()
{
    int i;
    float[] b = new float[10];
    for (i = 0; i < 10; i++)
    {	//printf("b[%d] = %d\n", i, b[i]);
	assert(isNaN(b[i]));
    }

    typedef float tfloat = 0.0;
    tfloat[] tb = new tfloat[63];
    for (i = 0; i < 63; i++)
	assert(tb[i] == cast(tfloat)0.0);
}

/************************************/
// failed to compile on DMD0.050, only with typedef (alias was OK)

typedef int[int] T11;
T11 a11;

void test15_test11()
{
    1 in a11;
}

/************************************/
// ICE(cgelem.c) on 0.050, alias was OK.
struct A12
{
    int x;
    int y;
    int x1;
    int x2;
}

typedef A12 B12;

template V12(T)
{
    T buf;

    T get()
    {
       return buf;
    }
}

alias V12!(B12) foo12;


void test15_test12()
{
    B12 b = foo12.get();
}

/************************************/
// test15_test13. Failed to compile DMD0.050, OK with alias.
typedef int[] T13;
static T13 a13=[1,2,3];

/************************************************/
// Failed to compile DMD0.050, OK with alias.

typedef int foo3;

foo3 [foo3] list3;

void testaa_test3()
{
    list3[cast(foo3)5] = cast(foo3)2;
    foo3 x = list3.keys[0]; // This line fails.
    assert(x == cast(foo3)5);
}


/*****************************************/

void test20_test32()
{
	typedef int Type = 12;
	static Type[5] var = [0:1, 3:2];

	assert(var[0] == 1);
	assert(var[1] == 12);
	assert(var[2] == 12);
	assert(var[3] == 2);
	assert(var[4] == 12);
}

/**************************************/

class A2
{
    T opCast(T)()
    {
        auto s = T.stringof;
        printf("A.opCast!(%.*s)\n", s.length, s.ptr);
        return T.init;
    }
}


void opover2_test2()
{
    auto a = new A2();

    auto x = cast(int)a;
    assert(x == 0);

    typedef int myint_BUG6712 = 7;
    auto y = cast(myint_BUG6712)a;
    assert(y == 7);
}

/**************************************/
// http://www.digitalmars.com/d/archives/10750.html
// test12.d, test7(). ICE(constfold.c)

template base7( T )
{
 void errfunc() { throw new Exception("no init"); }
 typedef T safeptr = cast(T)&errfunc;
}

alias int function(int) mfp;
alias base7!(mfp) I_V_fp;

typedef bool antibool = 1;
antibool[8] z21 = [ cast(antibool) 0, ];

void test12_test21()
{
    assert(z21[7]);
}

/**************************************/
// test12.d, test41.
// Might be related to this:
// http://www.digitalmars.com/d/archives/digitalmars/D/INVALID_HANDLE_VALUE_const_55633.html

typedef void* H41;

const H41 INVALID_H41_VALUE = cast(H41)-1;

/*******************************************/

struct Ranged(T)
{
    T value, min, max, range;
}

typedef Ranged!(float) Degree = {0f, 0f, 360f, 360f};

void test28_test5()
{
    static Degree a;
    assert(a.value == 0f);
    assert(a.min == 0f);
    assert(a.max == 360f);
    assert(a.range == 360f);
}

/*******************************************/

void test28_test6()
{
    struct Foo
    {
        void foo() { }
    }

    typedef Foo Bar;

    Bar a;
    a.foo();
}

/*******************************************/

typedef uint socket_t = -1u;

class Socket
{
    socket_t sock;

    void accept()
    {
	    socket_t newsock;
    }
}

void test28_test16()
{
}

/*******************************************/

typedef int Xint = 42;

void test28_test56()
{
    Xint[3][] x = new Xint[3][4];

    foreach(Xint[3] i; x) {
        foreach (Xint j; i)
            assert(j == 42);
    }
}

void test28_test57()
{
    Xint[3][] x = new Xint[3][4];
    x.length = 200;
    assert(x.length == 200);

    foreach(Xint[3] i; x) {
        foreach (Xint j; i)
            assert(j == 42);
    }
}
/******************************************/
// from runnable/traits.d
typedef int traits_myint;
static assert(__traits(isArithmetic, traits_myint) == true);
static assert(__traits(isScalar, traits_myint) == true);
static assert(__traits(isIntegral, traits_myint) == true);

mixin template Members6674()
{
    static int i1;
    static int i2;
    static int i3;  //comment out to make func2 visible
    static int i4;  //comment out to make func1 visible
}

class Test6674
{
    mixin Members6674;

    typedef void function() func1;
    typedef bool function() func2;
}

static assert([__traits(allMembers,Test6674)] == [
    "i1","i2","i3","i4",
    "func1","func2",
    "toString","toHash","opCmp","opEquals","Monitor","factory"]);

/***************************************************/
// Bug 1523. typedef only.

struct BaseStruct {
  int n;
  char c;
}

typedef BaseStruct MyStruct26;

void myFunction(MyStruct26) {}

void test42_test26()
{
  myFunction(MyStruct26(0, 'x'));
}

/***************************************************/
// typedef only

class Foo30
{
    int i;
}

typedef Foo30 Bar30;

void test42_test30()
{
    Bar30 testBar = new Bar30();
    auto j = testBar.i;
}

/***************************************************/
// test55. bug 1767

class DebugInfo
{
    typedef int CVHeaderType ;
    enum anon:CVHeaderType{ CV_NONE, CV_DOS, CV_NT, CV_DBG }
}

/***************************************************/

void test42_test102()
{
    typedef const(char)[] A;
    A stripl(A s)
    {
	uint i;
	return s[i .. $];
    }
}

/***************************************************/
// test42.d test107(). segfault 2.020
class foo107 {}
typedef foo107 bar107;
void x107()
{
   bar107 a = new bar107();
   bar107 b = new bar107();
   bool c = (a == b);
}

/***************************************************/
// Bug 3668. segfault regression 2.032.

void test42_test167()
{
    typedef byte[] Foo;
    Foo bar;
    foreach(value; bar){}
}


// Bug 190. Test42.d, test 225.

typedef int avocado;
void eat(avocado x225 = .x225);
avocado x225;

/***************************************************/

typedef ireal BUG3919;
alias typeof(BUG3919.init*BUG3919.init) ICE3919;
alias typeof(BUG3919.init/BUG3919.init) ICE3920;

/*****************************************/
// rejectsvalid 0.100. typedef only.

void testswitch_test18()
{
    enum E { a, b }
    typedef E F;
    F i = E.a;
    final switch (i)
    {
	case E.a:
	case E.b:
	    break;
    }
}

/************************************/

void testconst_test7()
{
    typedef void *HANDLE;
    const HANDLE INVALID_HANDLE_VALUE = cast(HANDLE)-1;
}

/************************************/

void testconst_test67()
{
    typedef char mychar;
    alias immutable(mychar)[] mystring;

    mystring s = cast(mystring)"hello";
    mychar c = s[0];
}

/************************************/

void testconst_test71()
{
    string s = "hello world";
    char c = s[0];

    typedef char mychar;
    alias immutable(mychar)[] mystring;

    mystring t = cast(mystring)("hello world");
    mychar d = t[0];
}

/************************************/

class foo86 { }

typedef shared foo86 Y86;

void testconst_test86()
{
   pragma(msg, Y86);
   shared(Y86) x = new Y86;
}

/******************************************/

int main()
{
    test2();
    test5();
    lexerTest7();
    test10();
    test19();
    test33();
    test41();
    test59();
    test60();
    test4_test26();
    test4_test28();
    structlit_test10();
    test15_test1();
    test15_test2();
    test15_test3();
    test15_test4();
    test15_test11();
    test15_test12();
    test20_test32();
    opover2_test2();
    test12_test21();
    test28_test5();
    test28_test6();
    test28_test16();
    test28_test56();
    test28_test57();
    testaa_test3();
    test42_test26();
    test42_test30();
    test42_test102();
    test42_test167();
    testswitch_test18();
    testconst_test7();
    testconst_test67();
    testconst_test71();
    testconst_test86();
    return 0;
}
