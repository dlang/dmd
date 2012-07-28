module ufcs;

extern (C) int printf(const char*, ...);

/*******************************************/

struct S {}

int foo(int n)          { return 1; }
int foo(int n, int m)   { return 2; }
int goo(int[] a)        { return 1; }
int goo(int[] a, int m) { return 2; }
int bar(S s)            { return 1; }
int bar(S s, int n)     { return 2; }

int baz(X)(X x)         { return 1; }
int baz(X)(X x, int n)  { return 2; }

int temp;
ref int boo(int n)      { return temp; }
ref int coo(int[] a)    { return temp; }
ref int mar(S s)        { return temp; }

ref int maz(X)(X x)     { return temp; }

void test1()
{
    int n;
    int[] a;
    S s;

    assert(   foo(4)    == 1);      assert(   baz(4)    == 1);
    assert( 4.foo()     == 1);      assert( 4.baz()     == 1);
    assert( 4.foo       == 1);      assert( 4.baz       == 1);
    assert(   foo(4, 2) == 2);      assert(   baz(4, 2) == 2);
    assert( 4.foo(2)    == 2);      assert( 4.baz(2)    == 2);
    assert((4.foo = 2)  == 2);      assert((4.baz = 2)  == 2);

    assert(   goo(a)    == 1);      assert(   baz(a)    == 1);
    assert( a.goo()     == 1);      assert( a.baz()     == 1);
    assert( a.goo       == 1);      assert( a.baz       == 1);
    assert(   goo(a, 2) == 2);      assert(   baz(a, 2) == 2);
    assert( a.goo(2)    == 2);      assert( a.baz(2)    == 2);
    assert((a.goo = 2)  == 2);      assert((a.baz = 2)  == 2);

    assert(   bar(s)    == 1);      assert(   baz(s)    == 1);
    assert( s.bar()     == 1);      assert( s.baz()     == 1);
    assert( s.bar       == 1);      assert( s.baz       == 1);
    assert(   bar(s, 2) == 2);      assert(   baz(s, 2) == 2);
    assert( s.bar(2)    == 2);      assert( s.baz(2)    == 2);
    assert((s.bar = 2)  == 2);      assert((s.baz = 2)  == 2);

    assert((  boo(4) = 2) == 2);    assert((  maz(4) = 2) == 2);
    assert((4.boo    = 2) == 2);    assert((4.maz    = 2) == 2);
    assert((  coo(a) = 2) == 2);    assert((  maz(a) = 2) == 2);
    assert((a.coo    = 2) == 2);    assert((a.maz    = 2) == 2);
    assert((  mar(s) = 2) == 2);    assert((  maz(s) = 2) == 2);
    assert((s.mar    = 2) == 2);    assert((s.maz    = 2) == 2);
}

int hoo(T)(int n)          { return 1; }
int hoo(T)(int n, int m)   { return 2; }
int koo(T)(int[] a)        { return 1; }
int koo(T)(int[] a, int m) { return 2; }
int var(T)(S s)            { return 1; }
int var(T)(S s, int n)     { return 2; }

int vaz(T, X)(X x)         { return 1; }
int vaz(T, X)(X x, int n)  { return 2; }

//int temp;
ref int voo(T)(int n)      { return temp; }
ref int woo(T)(int[] a)    { return temp; }
ref int nar(T)(S s)        { return temp; }

ref int naz(T, X)(X x)     { return temp; }

void test2()
{
    int n;
    int[] a;
    S s;

    assert(   hoo!int(4)    == 1);  assert(   vaz!int(4)    == 1);
    assert( 4.hoo!int()     == 1);  assert( 4.vaz!int()     == 1);
    assert( 4.hoo!int       == 1);  assert( 4.vaz!int       == 1);
    assert(   hoo!int(4, 2) == 2);  assert(   vaz!int(4, 2) == 2);
    assert( 4.hoo!int(2)    == 2);  assert( 4.vaz!int(2)    == 2);
    assert((4.hoo!int = 2)  == 2);  assert((4.vaz!int = 2)  == 2);

    assert(   koo!int(a)    == 1);  assert(   vaz!int(a)    == 1);
    assert( a.koo!int()     == 1);  assert( a.vaz!int()     == 1);
    assert( a.koo!int       == 1);  assert( a.vaz!int       == 1);
    assert(   koo!int(a, 2) == 2);  assert(   vaz!int(a, 2) == 2);
    assert( a.koo!int(2)    == 2);  assert( a.vaz!int(2)    == 2);
    assert((a.koo!int = 2)  == 2);  assert((a.vaz!int = 2)  == 2);

    assert(   var!int(s)    == 1);  assert(   vaz!int(s)    == 1);
    assert( s.var!int()     == 1);  assert( s.vaz!int()     == 1);
    assert( s.var!int       == 1);  assert( s.vaz!int       == 1);
    assert(   var!int(s, 2) == 2);  assert(   vaz!int(s, 2) == 2);
    assert( s.var!int(2)    == 2);  assert( s.vaz!int(2)    == 2);
    assert((s.var!int = 2)  == 2);  assert((s.vaz!int = 2)  == 2);

    assert((  voo!int(4) = 2) == 2);    assert((  naz!int(4) = 2) == 2);
    assert((4.voo!int    = 2) == 2);    assert((4.naz!int    = 2) == 2);
    assert((  woo!int(a) = 2) == 2);    assert((  naz!int(a) = 2) == 2);
    assert((a.woo!int    = 2) == 2);    assert((a.naz!int    = 2) == 2);
    assert((  nar!int(s) = 2) == 2);    assert((  naz!int(s) = 2) == 2);
    assert((s.nar!int    = 2) == 2);    assert((s.naz!int    = 2) == 2);
}

/*******************************************/

auto init(T)(T val) { return 1; }

auto sort(alias fun, T)(T val) { return 1; }

@property auto max(alias fun, T)(T val) { return 1; }

@property auto infinity(alias opt, T)(T val) { return 1; }

void test3()
{
    // See built-in 'init' property
    assert(1    .init == 0);
    assert([1]  .init == null);
    assert([1:1].init == null);
    assert(1.0  .init is double.nan);
    assert(10i  .init is idouble.nan);
    assert('c'  .init == 0xFF);
    assert("s"  .init == null);

    // x.init() has parens, so it runs UFCS call
    assert( 1   .init() == 1);
    assert([1]  .init() == 1);
    assert([1:1].init() == 1);
    assert(1.0  .init() == 1);
    assert(10i  .init() == 1);
    assert('c'  .init() == 1);
    assert("s"  .init() == 1);

    // x.init!YYY matches templatized UFCS call.
    assert( 1   .init!int()        == 1);
    assert([1]  .init!(int[])()    == 1);
    assert([1:1].init!(int[int])() == 1);
    assert(1.0  .init!double()     == 1);
    assert(10i  .init!idouble()    == 1);
    assert('c'  .init!char()       == 1);
    assert("s"  .init!string()     == 1);

    assert([1].sort!"a<b"() == 1);
    assert([1].sort == [1]);

    // templatized properties runs UFCS call.
    assert(1024.max!"a<b" == 1);
    assert(1024.max  == int.max);

    assert(3.14.infinity!"+" == 1);
    assert(3.14.infinity == (double).infinity);
}

/*******************************************/
// 662

import std.stdio,std.string, std.conv;

enum Etest
{
    a,b,c,d
}

//typedef int testi = 10;
//typedef Test Test2;

int test() { return 33; }

class Test
{
    static int test(int i) { return i; }
}

int test(Etest test)
{
    return cast(int)test;
}

//int test(testi i)
//{
//  return cast(int)i;
//}

void test682()
{
    assert(22.to!string() == "22");
    assert((new Test).test(11) == 11);
    assert(Test.test(11) == 11);
    //assert(Test2.test(11) == 11);
    assert(test() == 33);
    assert(ufcs.test() == 33);
    assert(Etest.d.test() == Etest.d);
    //testi i;
    //assert(i.test() == i.init);
}

/*******************************************/
// 3382

import std.range, std.algorithm;

@property T twice(T)(T x){ return x * x; }
real toreal(ireal x){ return x.im; }
char toupper(char c){ return ('a'<=c && c<='z') ? cast(char)(c - 'a' + 'A') : c; }

@property ref T setter(T)(ref T x, T v){ x = v; return x; }

void test3382()
{
    auto r = iota(0, 10).map!"a*3"().filter!"a%2 != 0"();
    foreach (e; r)
        printf("e = %d\n", e);

    assert(10.twice == 100);
    assert(0.5.twice == 0.25);
    assert(1.4i.toreal() == 1.4);
    assert('c'.toupper() == 'C');
}

/*******************************************/
// 7670

struct A7670
{
    double x;
}
@property ref double y7670(ref A7670 a)
{
    return a.x;
}
void test7670()
{
    A7670 a1;
    a1.y7670() = 2.0; // OK
    a1.y7670 = 2.0; // Error
}

/*******************************************/
// 7703
void f7703(T)(T a) { }

void test7703()
{
    int x;
    x.f7703;        // accepted
    x.f7703();      // accepted
    x.f7703!int;    // rejected -- "f(x) isn't a template"
    x.f7703!int();  // accepted
}

/*******************************************/
// 7773

//import std.stdio;
void writeln7773(int n){}
void test7773()
{
    (int.max).writeln7773(); // OK
    int.max.writeln7773();   // error
}

/*******************************************/
// 7943

struct Foo7943
{
    int _member;
    alias _member this;
}

int foo7943(Foo7943 f) { return 1; }
int foo7943(int i) { return 2; }

void test7943()
{
    Foo7943 f;
    assert(f.foo7943() == 1);
}

/*******************************************/
// 8180

int writeln8180(T...)(T args) { return 1; }

struct Tuple8180(T...)
{
    T field;
    alias field this;
}

void test8180()
{
    auto t = Tuple8180!(int)(10);
    assert(t.writeln8180() == 1);
}

/*******************************************/
// 8252

bool f(int x) { return !x; }

void test8252()
{
    static assert(!1.f); // ok
    static assert( 0.f); // fail
}

/*******************************************/
// 8453

T[] sort8453(T)(T[] a) { return a; }

void test8453()
{
    int[int] foo;
    auto bar1 = foo.keys().sort8453(); // OK
    auto bar2 = foo.keys.sort8453();   // Error
}

/*******************************************/

template Signal4()
{
    void connect(){}
}
struct S4
{
    mixin Signal4!() s;
}
void test4()
{
    S4 s;
    s.s.connect();  // s.s is TOKdotexp, so never match UFCS
}

/*******************************************/

int main()
{
    test1();
    test2();
    test3();
    test682();
    test3382();
    test7670();
    test7703();
    test7773();
    test7943();
    test8180();
    test8252();
    test8453();
    test4();

    printf("Success\n");
    return 0;
}
