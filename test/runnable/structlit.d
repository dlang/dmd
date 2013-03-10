import std.stdio;

struct S
{
    int x;
    int y;
}

/********************************************/

void test1()
{
    S s = S(1,2);
    assert(s.x == 1);
    assert(s.y == 2);
}

/********************************************/

void foo2(S s)
{
    assert(s.x == 1);
    assert(s.y == 2);
}

void test2()
{
    foo2( S(1,2) );
}

/********************************************/

S foo3()
{
    return S(1, 2);
}

void test3()
{
    S s = foo3();
    assert(s.x == 1);
    assert(s.y == 2);
}

/********************************************/

struct S4
{
    long x;
    long y;
    long z;
}

S4 foo4()
{
    return S4(1, 2, 3);
}

void test4()
{
    S4 s = foo4();
    assert(s.x == 1);
    assert(s.y == 2);
    assert(s.z == 3);
}

/********************************************/

struct S5
{
    long x;
    char y;
    long z;
}

S5 foo5()
{
    return S5(1, 2, 3);
}

void test5()
{
    S5 s = foo5();
    assert(s.x == 1);
    assert(s.y == 2);
    assert(s.z == 3);
}

/********************************************/

struct S6
{
    long x;
    char y;
    long z;
}

void test6()
{
    S6 s1 = S6(1,2,3);
    S6 s2 = S6(1,2,3);
    assert(s1 == s2);

    s1 = S6(4,5,6);
    s2 = S6(4,5,6);
    assert(s1 == s2);

    S6* p1 = &s1;
    S6* p2 = &s2;
    *p1 = S6(7,8,9);
    *p2 = S6(7,8,9);
    assert(*p1 == *p2);
}

/********************************************/

struct S7
{
    long x;
    char y;
    long z;
}

void test7()
{
    static S7 s1 = S7(1,2,3);
    static S7 s2 = S7(1,2,3);
    assert(s1 == s2);
}

/********************************************/

struct S8
{
    int i;
    string s;
}

void test8()
{
    S8 s = S8(3, "hello");
    assert(s.i == 3);
    assert(s.s == "hello");

    static S8 t = S8(4, "betty");
    assert(t.i == 4);
    assert(t.s == "betty");

    S8 u = S8(3, ['h','e','l','l','o']);
    assert(u.i == 3);
    assert(u.s == "hello");

    static S8 v = S8(4, ['b','e','t','t','y']);
    assert(v.i == 4);
    assert(v.s == "betty");
}

/********************************************/

struct S9
{
    int i;
    char[5] s;
}

void test9()
{
    S9 s = S9(3, "hello");
    assert(s.i == 3);
    assert(s.s == "hello");

    static S9 t = S9(4, "betty");
    assert(t.i == 4);
    assert(t.s == "betty");

    S9 u = S9(3, ['h','e','l','l','o']);
    assert(u.i == 3);
    assert(u.s == "hello");

    static S9 v = S9(4, ['b','e','t','t','y']);
    assert(v.i == 4);
    assert(v.s == "betty");
}

/********************************************/

alias int myint10;

struct S10
{
    int i;
    union
    {
        int x = 2;
        int y;
    }
    int j = 3;
    myint10 k = 4;
}

void test10()
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

/********************************************/

struct S11
{
    int i;
    int j = 3;
}


void test11()
{
    static const s = S11( 1, 5 );
    static const i = s.i;
    assert(i == 1);
    static assert(s.j == 5);
}

/********************************************/

struct S12
{
    int[5] x;
    int[5] y = 3;
}

void test12()
{
    S12 s = S12();
    foreach (v; s.x)
        assert(v == 0);
    foreach (v; s.y)
        assert(v == 3);
}

/********************************************/

struct S13
{
    int[5] x;
    int[5] y;
    int[6][3] z;
}

void test13()
{
    S13 s = S13(0,3,4);
    foreach (v; s.x)
        assert(v == 0);
    foreach (v; s.y)
        assert(v == 3);
    for (int i = 0; i < 6; i++)
    {
        for (int j = 0; j < 3; j++)
        {
            assert(s.z[j][i] == 4);
        }
    }
}

/********************************************/

struct S14a { int n; }
struct S14b { this(int n){} }

void foo14(ref S14a s) {}
void foo14(ref S14b s) {}
void hoo14()(ref S14a s) {}
void hoo14()(ref S14b s) {}
void poo14(S)(ref S s) {}

void bar14(S14a s) {}
void bar14(S14b s) {}
void var14()(S14a s) {}
void var14()(S14b s) {}
void war14(S)(S s) {}

int baz14(    S14a s) { return 1; }
int baz14(ref S14a s) { return 2; }
int baz14(    S14b s) { return 1; }
int baz14(ref S14b s) { return 2; }
int vaz14()(    S14a s) { return 1; }
int vaz14()(ref S14a s) { return 2; }
int vaz14()(    S14b s) { return 1; }
int vaz14()(ref S14b s) { return 2; }
int waz14(S)(    S s) { return 1; }
int waz14(S)(ref S s) { return 2; }

void test14()
{
    // can not bind rvalue-sl with ref
    static assert(!__traits(compiles, foo14(S14a(0))));
    static assert(!__traits(compiles, foo14(S14b(0))));
    static assert(!__traits(compiles, hoo14(S14a(0))));
    static assert(!__traits(compiles, hoo14(S14b(0))));
    static assert(!__traits(compiles, poo14(S14a(0))));
    static assert(!__traits(compiles, poo14(S14b(0))));

    // still can bind rvalue-sl with non-ref
    bar14(S14a(0));
    bar14(S14b(0));
    var14(S14a(0));
    var14(S14b(0));
    war14(S14a(0));
    war14(S14b(0));

    // preferred binding of rvalue-sl in overload resolution
    assert(baz14(S14a(0)) == 1);
    assert(baz14(S14b(0)) == 1);
    assert(vaz14(S14a(0)) == 1);
    assert(vaz14(S14b(0)) == 1);
    assert(waz14(S14a(0)) == 1);
    assert(waz14(S14b(0)) == 1);
}

/********************************************/

struct Bug1914a
{
    const char[10] i = [1,0,0,0,0,0,0,0,0,0];
    char[10] x = i;
    int y=5;
}

struct Bug1914b
{
    const char[10] i = [0,0,0,0,0,0,0,0,0,0];
    char[10] x = i;
    int y=5;
}

struct Bug1914c
{
    const char[2] i = ['a', 'b'];
    const char[2][3] j = [['x', 'y'], ['p', 'q'], ['r', 's']];
    const char[2][3] k = ["cd", "ef", "gh"];
    const char[2][3] l = [['x', 'y'], ['p'], ['h', 'k']];
    char[2][3] x = i;
    int y = 5;
    char[2][3] z = j;
    char[2][3] w = k;
    int v=27;
    char[2][3] u = l;
    int t = 718;
}

struct T3198 {
   int g = 1;
}

class Foo3198 {
   int[5] x = 6;
   T3198[5] y = T3198(4);
}

void test3198and1914()
{
    Bug1914a a;
    assert(a.y==5, "bug 1914, non-zero init");
    Bug1914b b;
    assert(b.y==5, "bug 1914, zero init");
    Bug1914c c;
    assert(c.y==5, "bug 1914, multilevel init");
    assert(c.v==27, "bug 1914, multilevel init2");
    assert(c.x[2][1]=='b');
    assert(c.t==718, "bug 1914, multi3");
    assert(c.u[1][0]=='p');
    assert(c.u[1][1]==char.init);
    auto f = new Foo3198();
    assert(f.x[0]==6);
    assert(f.y[0].g==4, "bug 3198");
}

/********************************************/

struct T5885 {
    uint a, b;
}

double mulUintToDouble(T5885 t, double m) {
    return t.a * m;
}

void test5885()
{
    enum ae = mulUintToDouble(T5885(10, 0), 10.0);
    enum be = mulUintToDouble(T5885(10, 20), 10.0);
    static assert(ae == be);

    auto a = mulUintToDouble(T5885(10, 0), 10.0);
    auto b = mulUintToDouble(T5885(10, 20), 10.0);
    assert(a == b);
}

/********************************************/
// 5889

struct S5889a { int n; }
struct S5889b { this(int n){} }

bool isLvalue(S)(auto ref S s){ return __traits(isRef, s); }

int foo(ref S5889a s) { return 1; }
int foo(    S5889a s) { return 2; }
int foo(ref S5889b s) { return 1; }
int foo(    S5889b s) { return 2; }

int goo(ref const(S5889a) s) { return 1; }
int goo(    const(S5889a) s) { return 2; }
int goo(ref const(S5889b) s) { return 1; }
int goo(    const(S5889b) s) { return 2; }

int too(S)(ref S s) { return 1; }
int too(S)(    S s) { return 2; }

S makeRvalue(S)(){ S s; return s; }

void test5889()
{
    S5889a sa;
    S5889b sb;

    assert( isLvalue(sa));
    assert( isLvalue(sb));
    assert(!isLvalue(S5889a(0)));
    assert(!isLvalue(S5889b(0)));
    assert(!isLvalue(makeRvalue!S5889a()));
    assert(!isLvalue(makeRvalue!S5889b()));

    assert(foo(sa) == 1);
    assert(foo(sb) == 1);
    assert(foo(S5889a(0)) == 2);
    assert(foo(S5889b(0)) == 2);
    assert(foo(makeRvalue!S5889a()) == 2);
    assert(foo(makeRvalue!S5889b()) == 2);

    assert(goo(sa) == 1);
    assert(goo(sb) == 1);
    assert(goo(S5889a(0)) == 2);
    assert(goo(S5889b(0)) == 2);
    assert(goo(makeRvalue!S5889a()) == 2);
    assert(goo(makeRvalue!S5889b()) == 2);

    assert(too(sa) == 1);
    assert(too(sb) == 1);
    assert(too(S5889a(0)) == 2);
    assert(too(S5889b(0)) == 2);
    assert(too(makeRvalue!S5889a()) == 2);
    assert(too(makeRvalue!S5889b()) == 2);
}

/********************************************/
// 6937

void test6937()
{
    static struct S
    {
        int x, y;
    }

    auto s1 = S(1, 2);
    auto ps1 = new S(1, 2);
    assert(ps1.x == 1);
    assert(ps1.y == 2);
    assert(*ps1 == s1);

    auto ps2 = new S(1);
    assert(ps2.x == 1);
    assert(ps2.y == 0);
    assert(*ps2 == S(1, 0));

    static assert(!__traits(compiles, new S(1,2,3)));

    int v = 0;
    struct NS
    {
        int x;
        void foo() { v = x; }
    }
    auto ns = NS(1);
    ns.foo();
    assert(ns.x == 1);
    assert(v == 1);
    auto pns = new NS(2);
    assert(pns.x == 2);
    pns.foo();
    assert(v == 2);
    pns.x = 1;
    assert(*pns == ns);

    static struct X {
        int v;
        this(this) { ++v; }
    }
    static struct Y {
        X x;
    }
    Y y = Y(X(1));
    assert(y.x.v == 1);
    auto py1 = new Y(X(1));
    assert(py1.x.v == 1);
    assert(*py1 == y);
    auto py2 = new Y(y.x);
    assert(py2.x.v == 2);
}

/********************************************/
// 7929

void test7929()
{
    static struct S
    {
        int [] numbers;
    }

    const int [] numbers = new int[2];
    const S si = {numbers};
    // Error: cannot implicitly convert expression (numbers) of type const(int[]) to int[]

    const S se = const(S)(numbers);
    // OK
}

/********************************************/
// 7021

struct S7021
{
    @disable this();
}

void test7021()
{
  static assert(!is(typeof({
    auto s = S7021();
  })));
}

/********************************************/
// 8763

void test8763()
{
    struct S
    {
        this(int) {}
    }

    void foo(T, Args...)(Args args)
    {
        T t = T(args);
        // Error: constructor main.S.this (int) is not callable using argument types ()
    }

    S t = S(); // OK, initialize to S.init
    foo!S();
}

/********************************************/
// 8902

union U8902 { int a, b; }

enum U8902 u8902a = U8902.init; // No errors
U8902 u8902b;                   // No errors
U8902 u8902c = U8902.init;      // Error: duplicate union initialization for b

void test8902()
{
    U8902 u8902d = U8902.init;                  // No errors
    immutable U8902 u8902e = U8902.init;        // No errors
    immutable static U8902 u8902f = U8902.init; // Error: duplicate union...
    static U8902 u8902g = u8902e;               // Error: duplicate union...
    static U8902 u8902h = U8902.init;           // Error: duplicate union...
}

/********************************************/
// 9116

void test9116()
{
    static struct X
    {
        int v;
        this(this) { ++v; }
    }
    static struct Y
    {
        X x;
    }
    X x = X(1);
    assert(x.v == 1);
    Y y = Y(X(1));
    //printf("y.x.v = %d\n", y.x.v);  // print 2, but should 1
    assert(y.x.v == 1); // fails
}

/********************************************/
// 9293

void test9293()
{
    static struct A
    {
    //  enum A zero = A(); // This works as expected
        enum A zero = {};  // Note the difference here

        int opCmp(const ref A a) const
        {
            assert(0);
        }

        int opCmp(const A a) const
        {
            return 0;
        }
    }

    A a;
    auto b = a >= A.zero;  // Error: A() is not an lvalue
}

/********************************************/
// 9566

void test9566()
{
    static struct ExpandData
    {
        ubyte[4096] window = 0;
    }
    ExpandData a;
    auto b = ExpandData.init;   // bug
}

/********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    test14();
    test3198and1914();
    test5885();
    test5889();
    test6937();
    test7929();
    test7021();
    test8763();
    test8902();
    test9116();
    test9293();
    test9566();

    printf("Success\n");
    return 0;
}
