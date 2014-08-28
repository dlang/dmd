// REQUIRED_ARGS: -d
// PERMUTE_ARGS: -dw

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

version(none) // This contains an incredibly nasty cast
{
template base7( T )
{
 void errfunc() { throw new Exception("no init"); }
 typedef T safeptr = cast(T)&errfunc; // Nasty cast
}

alias int function(int) mfp;
alias base7!(mfp) I_V_fp;
}

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

/************************************/

class Class19 : Throwable
{
    this() { super(""); }
}

typedef Class19 Alias19;

void testdstress_test19()
{
	try{
		throw new Alias19();
	}catch{
		return;
	}
	assert(0);
}
/************************************/

public static const uint U20 = (cast(uint)(-1)) >>> 2;

typedef uint myType20;
public static const myType20 T20 = (cast(myType20)(-1)) >>> 2;

void testdstress_test20()
{
	assert(U20 == 0x3FFFFFFF);
	assert(T20 == 0x3FFFFFFF);
}

/******************************************************/

class ABC { }

typedef ABC DEF;

TypeInfo foo()
{
    ABC c;

    return typeid(DEF);
}

void testtypeid_test1()
{
    TypeInfo ti = foo();

    TypeInfo_Typedef td = cast(TypeInfo_Typedef)ti;
    assert(td);

    ti = td.base;

    TypeInfo_Class tc = cast(TypeInfo_Class)ti;
    assert(tc);

    printf("%.*s\n", tc.info.name.length, tc.info.name.ptr);
    assert(tc.info.name == "deprecate1.ABC");
}

/******************************************************/

union MyUnion5{
	int i;
	byte b;
}

typedef MyUnion5* Foo5;

void testtypeid_test5()
{
	TypeInfo ti = typeid(Foo5);
	assert(!(ti is null));
	assert(ti.tsize==(Foo5).sizeof);
	assert(ti.toString()=="deprecate1.Foo5");
}

/***********************************/
// test8.d test13()
typedef void *HWND;

const HWND hWnd = cast(HWND)(null);

/***********************************/

typedef int* IP;

void test8_test21()
{
    int i = 5;
    IP ip = cast(IP) &i;
    assert(*ip == 5);
}

/***********************************/
// http://www.digitalmars.com/d/archives/7812.html

typedef int delegate() DG;

class A23 {
    int foo() { return 7; }
    DG pfoo() { return &this.foo; } //this is ok
}

void test8_test23()
{
    int i;
    A23 a = new A23;
    DG dg = &a.foo;
    i = dg();
    assert(i == 7);
    DG dg2 = a.pfoo();
    i = dg2();
    assert(i == 7);
}

/***********************************/
// test8 test29()
typedef int[] tint;

void Set( ref tint array, int newLength )
{
    array.length= newLength;
}

/***********************************/

struct V41 { int x; }

typedef V41 W41 = { 3 };

class Node41
{
   W41 v;
}

void test8_test41()
{
    Node41 n = new Node41;

    printf("n.v.x == %d\n", n.v.x);
    assert(n.v.x == 3);
}

/***********************************/
// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/1801.html
// test8 test47. ICE(e2ir.c)

typedef string Qwert47;

string yuiop47(Qwert47 asdfg)
{
    return asdfg[4..6];
}

/***********************************/
void test22_test28()
{
    typedef cdouble Y;
    Y five = cast(Y) (4.0i + 0.4);
}

/*******************************************/
// Bug 184

struct vegetarian
{
    carrots areYummy;
}

typedef ptrdiff_t carrots;

void test23_test35()
{
    assert(vegetarian.sizeof == ptrdiff_t.sizeof);
}

/*******************************************/
// bug 185
void test23_test36()
{
        typedef double type = 5.0;

        type t;
        assert (t == type.init);

        type[] ts = new type[10];
        ts.length = 20;
        foreach (i; ts)
	{
	    assert(i == cast(type)5.0);
	}
}

/*******************************************/

typedef int Int1; 
typedef int Int2; 

int show(Int1 v)
{
    printf("Int1: %d", v); 
    return 1;
}

int show(Int2 v) {
    printf("Int2: %d", v); 
    return 2;
}

int show(int i) { 
    printf("int: %d", i); 
    return 3;
}

int show(long l) {
    printf("long: %d", l);
    return 4;
}

int show(uint u) { 
    printf("uint: %d", u); 
    return 5;
}

void test23_test49()
{   int i;

    Int1 value1 = 42; 
    Int2 value2 = 69; 

    i = show(value1 + value2); 
    assert(i == 3);
    i = show(value2 + value1); 
    assert(i == 3);
    i = show(2 * value1); 
    assert(i == 3);
    i = show(value1 * 2); 
    assert(i == 3);
    i = show(value1 + value1); 
    assert(i == 1);
    i = show(value2 - value2); 
    assert(i == 2);
    i = show(value1 + 2); 
    assert(i == 3);
    i = show(3 + value2); 
    assert(i == 3);
    i = show(3u + value2); 
    assert(i == 5);
    i = show(value1 + 3u); 
    assert(i == 5);

    long l = 23; 
    i = show(value1 + l); 
    assert(i == 4);
    i = show(l + value2); 
    assert(i == 4);

    short s = 105; 
    i = show(s + value1); 
    assert(i == 3);
    i = show(value2 + s); 
    assert(i == 3);
}

/*******************************************/

void test23_test51()
{
    typedef int fooQ = 10;

    int[3][] p = new int[3][5];
    int[3][] q = new int[3][](5);

    int[][]  r = new int[][](5,3);

    for (int i = 0; i < 5; i++)
    {
	for (int j = 0; j < 3; j++)
	{
	    assert(r[i][j] == 0);
	    r[i][j] = i * j;
	}
    }

    fooQ[][]  s = new fooQ[][](5,3);

    for (int i = 0; i < 5; i++)
    {
	for (int j = 0; j < 3; j++)
	{
	    assert(s[i][j] == 10);
	    s[i][j] = cast(fooQ)(i * j);
	}
    }

    typedef fooQ[][] barQ;
    barQ b = new barQ(5,3);

    for (int i = 0; i < 5; i++)
    {
	for (int j = 0; j < 3; j++)
	{
	    assert(b[i][j] == 10);
	    b[i][j] = cast(fooQ)(i * j);
	}
    }
}

/*******************************************/

typedef ubyte x53 = void;

void test23_test53()
{
    new x53[10];
}

/*******************************************/

void test23_test55()
{
    typedef uint myintX = 6;

    myintX[500][] data;

    data.length = 1;
    assert(data.length == 1);
    foreach (ref foo; data)
    {
	assert(foo.length == 500);
	foreach (ref u; foo)
	{   //printf("u = %u\n", u);
	    assert(u == 6);
	    u = 23;
	}
    }
    foreach (ref foo; data)
    {
	assert(foo.length == 500);
	foreach (u; foo)
	{   assert(u == 23);
	    auto v = u;
	    v = 23;
	}
    }

    typedef byte mybyte = 7;

    mybyte[500][] mata;

    mata.length = 1;
    assert(mata.length == 1);
    foreach (ref foo; mata)
    {
	assert(foo.length == 500);
	foreach (ref u; foo)
	{   //printf("u = %u\n", u);
	    assert(u == 7);
	    u = 24;
	}
    }
    foreach (ref foo; mata)
    {
	assert(foo.length == 500);
	foreach (u; foo)
	{   assert(u == 24);
	    auto v = u;
	    v = 24;
	}
    }
}

/*******************************************/

typedef string String67;

int f67( string c,  string a )
{
    return 1;
}

int f67( string c, String67 a )
{
    return 2;
}

void test23_test67()
{
    printf("test67()\n");
    int i;
    i = f67( "", "" );
    assert(i == 1);
    i = f67( "", cast(String67)"" );
    assert(i == 2);
    i = f67( null, "" );
    assert(i == 1);
    i = f67( null, cast(String67)"" );
    assert(i == 2);
}

/************************************************/

void test34_test14()
{
    typedef Exception TypedefException;

    try
    {
    }
    catch(TypedefException e)
    {
    }
}

/************************************************/

void test34_test52()
{

    struct Foo {
	typedef int Y;
    }
    with (Foo) {
         Y y;
    }
}

/***************************************************/


void test6289()
{
    typedef immutable(int)[] X;
    static assert(is(typeof(X.init[]) == X));
    static assert(is(typeof((immutable(int[])).init[]) == immutable(int)[]));
    static assert(is(typeof((const(int[])).init[]) == const(int)[]));
    static assert(is(typeof((const(int[3])).init[]) == const(int)[]));
}

/***************************************************/
// 4237

struct Struct4237(T) { T value; }
void foo4237()
{
    typedef int Number = 1;
    Struct4237!Number s;
    pragma(msg, typeof(s).mangleof);
    assert(s.value == 1);
}
void bar4237()
{
    typedef real Number = 2;
    Struct4237!Number s;
    pragma(msg, typeof(s).mangleof);
    assert(s.value == 2); // Assertion failure
}
void test4237()
{
    foo4237(); bar4237();
}

/******************************************/
// from extra-files/test2.d

typedef void* HANDLE18;

HANDLE18 testx18()
{
    return null;
}

void test18()
{
    assert(testx18() is null);
}

/******************************************/

int main()
{
    test2();
    test5();
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
    testdstress_test19();
    testdstress_test20();
    testtypeid_test1();
    testtypeid_test5();
    test8_test21();
    test8_test23();
    test8_test41();
    test22_test28();
    test23_test35();
    test23_test36();
    test23_test49();
    test23_test51();
    test23_test53();
    test23_test55();
    test23_test67();
    test34_test14();
    test34_test52();
    test6289();
    test4237();
    test18();

    return 0;
}
