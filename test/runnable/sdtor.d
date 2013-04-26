
import core.vararg;

extern (C) int printf(const(char*) fmt, ...);

template TypeTuple(T...) { alias TypeTuple = T; }

/**********************************/

int sdtor;

struct S1
{
    ~this() { printf("~S()\n"); sdtor++; }
}

void test1()
{
    S1* s = new S1();
    delete s;
    assert(sdtor == 1);
}

/**********************************/

int sdtor2;

struct S2
{
    ~this() { printf("~S2()\n"); sdtor2++; }
    delete(void* p) { assert(sdtor2 == 1); printf("S2.delete()\n"); sdtor2++; }
}

void test2()
{
    S2* s = new S2();
    delete s;
    assert(sdtor2 == 2);
}

/**********************************/

int sdtor3;

struct S3
{   int a;
    ~this() { printf("~S3()\n"); sdtor3++; assert(a == 3); }
}

struct T3
{
    int i;
    S3 s;
}

void test3()
{
    T3* s = new T3();
    s.s.a = 3;
    delete s;
    assert(sdtor3 == 1);
}

/**********************************/

int sdtor4;

struct S4
{   int a = 3;
    ~this()
    {   printf("~S4()\n");
        if (a == 4)
            assert(sdtor4 == 2);
        else
        {   assert(a == 3);
            assert(sdtor4 == 1);
        }
        sdtor4++;
    }
}

struct T4
{
    int i;
    S4 s;
    ~this() { printf("~T4()\n"); assert(sdtor4 == 0); sdtor4++; }
    S4 t;
}

void test4()
{
    T4* s = new T4();
    s.s.a = 4;
    delete s;
    assert(sdtor4 == 3);
}

/**********************************/

int sdtor5;

template M5()
{  ~this()
   {
        printf("~M5()\n"); assert(sdtor5 == 1); sdtor5++;
   }
}

struct T5
{
    mixin M5 m;
    ~this() { printf("~T5()\n"); assert(sdtor5 == 0); sdtor5++; }
}

void test5()
{
    T5* s = new T5();
    delete s;
    assert(sdtor5 == 2);
}

/**********************************/

int sdtor6;

struct S6
{   int b = 7;
    ~this()
    {
        printf("~S6()\n"); assert(b == 7); assert(sdtor6 == 1); sdtor6++;
    }
}

class T6
{
    int a = 3;
    S6 s;
    ~this() { printf("~T6()\n"); assert(a == 3); assert(sdtor6 == 0); sdtor6++; }
}

void test6()
{
    T6 s = new T6();
    delete s;
    assert(sdtor6 == 2);
}

/**********************************/

int sdtor7;

struct S7
{   int b = 7;
    ~this()
    {
        printf("~S7()\n");
        assert(b == 7);
        assert(sdtor7 >= 1 && sdtor7 <= 3);
        sdtor7++;
    }
}

struct T7
{
    int a = 3;
    S7[3] s;
    ~this()
    {   printf("~T7() %d\n", sdtor7);
        assert(a == 3);
        assert(sdtor7 == 0);
        sdtor7++;
    }
}

void test7()
{
    T7* s = new T7();
    delete s;
    assert(sdtor7 == 4);
}

/**********************************/

int sdtor8;

struct S8
{   int b = 7;
    int c;
    ~this()
    {
        printf("~S8() %d\n", sdtor8);
        assert(b == 7);
        assert(sdtor8 == c);
        sdtor8++;
    }
}

void test8()
{
    S8[] s = new S8[3];
    s[0].c = 2;
    s[1].c = 1;
    s[2].c = 0;
    delete s;
    assert(sdtor8 == 3);
}

/**********************************/

int sdtor9;

struct S9
{   int b = 7;
    ~this()
    {
        printf("~S9() %d\n", sdtor9);
        assert(b == 7);
        sdtor9++;
    }
}

void test9()
{
    {
    S9 s;
    }
    assert(sdtor9 == 1);
}

/**********************************/

int sdtor10;

struct S10
{   int b = 7;
    int c;
    ~this()
    {
        printf("~S10() %d\n", sdtor10);
        assert(b == 7);
        assert(sdtor10 == c);
        sdtor10++;
    }
}

void test10()
{
    {
    S10[3] s;
    s[0].c = 2;
    s[1].c = 1;
    s[2].c = 0;
    }
    assert(sdtor10 == 3);
}

/**********************************/

int sdtor11;

template M11()
{   ~this()
    {
        printf("~M11()\n"); assert(sdtor11 == 1); sdtor11++;
    }
}

class T11
{
    mixin M11 m;
    ~this() { printf("~T11()\n"); assert(sdtor11 == 0); sdtor11++; }
}

void test11()
{
    T11 s = new T11();
    delete s;
    assert(sdtor11 == 2);
}

/**********************************/

int sdtor12;

struct S12
{   int a = 3;
    ~this() { printf("~S12() %d\n", sdtor12); sdtor12++; }
}

void foo12(S12 s)
{
}

void test12()
{
    {
    S12 s;
    foo12(s);
    s.a = 4;
    }
    assert(sdtor12 == 2);
}

/**********************************/

struct S13
{   int a = 3;
    int opAssign(S13 s)
    {
        printf("S13.opAssign(%p)\n", &this);
        a = 4;
        return s.a + 2;
    }
}

void test13()
{
    S13 s;
    S13 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S14
{   int a = 3;
    int opAssign(ref S14 s)
    {
        printf("S14.opAssign(%p)\n", &this);
        a = 4;
        return s.a + 2;
    }
}

void test14()
{
    S14 s;
    S14 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S15
{   int a = 3;
    int opAssign(ref const S15 s)
    {
        printf("S15.opAssign(%p)\n", &this);
        a = 4;
        return s.a + 2;
    }
}

void test15()
{
    S15 s;
    S15 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S16
{   int a = 3;
    int opAssign(S16 s, ...)
    {
        printf("S16.opAssign(%p)\n", &this);
        a = 4;
        return s.a + 2;
    }
}

void test16()
{
    S16 s;
    S16 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S17
{   int a = 3;
    int opAssign(...)
    {
        printf("S17.opAssign(%p)\n", &this);
        a = 4;
        return 5;
    }
}

void test17()
{
    S17 s;
    S17 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S18
{   int a = 3;
    int opAssign(S18 s, int x = 7)
    {
        printf("S18.opAssign(%p)\n", &this);
        a = 4;
        assert(x == 7);
        return s.a + 2;
    }
}

void test18()
{
    S18 s;
    S18 t;
    assert((s = t) == 5);
    assert(s.a == 4);
}

/**********************************/

struct S19
{
    int a,b,c,d;
    this(this) { printf("this(this) %p\n", &this); }
    ~this() { printf("~this() %p\n", &this); }
}

S19 foo19()
{
    S19 s;
    void bar() { s.a++; }
    bar();
    return s;
}

void test19()
{
    S19 t = foo19();
    printf("-main()\n");
}

/**********************************/

struct S20
{
    static char[] r;
    int a,b,c=2,d;
    this(this) { printf("this(this) %p\n", &this); r ~= '='; }
    ~this() { printf("~this() %p\n", &this); r ~= '~'; }
}

void foo20()
{
    S20 s;
    S20[3] a;
    assert(S20.r == "");
    a = s;
    assert(S20.r == "=~=~=~");
}

void test20()
{
    foo20();
    assert(S20.r == "=~=~=~~~~~");
    printf("-main()\n");
}

/**********************************/

struct S21
{
    static char[] r;
    int a,b,c=2,d;
    this(this) { printf("this(this) %p\n", &this); r ~= '='; }
    ~this() { printf("~this() %p\n", &this); r ~= '~'; }
}

void foo21()
{
    S21 s;
    S21[3] a = s;
    assert(S21.r == "===");
    S21.r = null;
    S21[3][2] b = s;
    assert(S21.r == "======");
    S21.r = null;
}

void test21()
{
    foo21();
    assert(S21.r == "~~~~~~~~~~");
    printf("-main()\n");
}

/**********************************/

struct S22
{
    static char[] r;
    int a,b,c=2,d;
    this(this) { printf("this(this) %p\n", &this); r ~= '='; }
    ~this() { printf("~this() %p\n", &this); r ~= '~'; }
}

void foo22()
{
    S22[3] s;
    S22[3][2] a;
    assert(S22.r == "");
    a = s;
    assert(S22.r == "===~~~===~~~");
    S22.r = null;
}

void test22()
{
    foo22();
    assert(S22.r == "~~~~~~~~~");
    printf("-main()\n");
}


/************************************************/

struct S23
{
    int m = 4, n, o, p, q;

    this(int x)
    {
        printf("S23(%d)\n", x);
        assert(x == 3);
        assert(m == 4 && n == 0 && o == 0 && p == 0 && q == 0);
        q = 7;
    }
}

void test23()
{
  {
    auto s = S23(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 4 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
  {
    auto s = new S23(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 4 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
  {
    S23 s;
    s = S23(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 4 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
}

/************************************************/

struct S24
{
    int m, n, o, p, q;

    this(int x)
    {
        printf("S24(%d)\n", x);
        assert(x == 3);
        assert(m == 0 && n == 0 && o == 0 && p == 0 && q == 0);
        q = 7;
    }
}

void test24()
{
  {
    auto s = S24(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 0 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
  {
    auto s = new S24(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 0 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
  {
    S24 s;
    s = S24(3);
    printf("s.m = %d, s.n = %d, s.q = %d\n", s.m, s.n, s.q);
    assert(s.m == 0 && s.n == 0 && s.o == 0 && s.p == 0 && s.q == 7);
  }
}

/**********************************/

struct S25
{
    this(int s) {}
}

void test25()
{
    auto a = S25();
}

/**********************************/

int z26;

struct A26
{
    int id;
    this(int x) { id = x; printf("Created A from scratch: %d\n", x); z26++; }
    this(this) { printf("Copying A: %d\n", id); z26 += 10; }
    ~this() { printf("Destroying A: %d\n", id); z26 += 100; }
}

struct B26
{
    A26 member;
    this(this) { printf("Copying B: %d\n", member.id); assert(0); }
}

B26 foo26()
{
    A26 a = A26(45);
    printf("1\n");
    assert(z26 == 1);
    return B26(a);
}

void test26()
{
    {
    auto b = foo26();
    assert(z26 == 111);
    printf("2\n");
    }
    assert(z26 == 211);
}

/**********************************/

int z27;

struct A27
{
    int id;
    this(int x) { id = x; printf("Ctor A27: %d\n", x); z27++; }
    this(this) { printf("Copying A27: %d\n", id); z27 += 10; }
    ~this() { printf("Destroying A27: %d\n", id); z27 += 100; }
}

struct B27
{
    A27[2][3] member;
}

void test27()
{
  {
    A27[2][3] a;
    assert(z27 == 0);
    B27 b = B27(a);
    assert(z27 == 60);
  }
  assert(z27 == 1260);
}


/**********************************/

string s28;

struct A28
{
    this(this)
    {
        printf("A's copy\n");
        s28 ~= "A";
    }
}

struct B28
{
    A28 member;
    this(this)
    {
        printf("B's copy\n");
        s28 ~= "B";
    }
}

void test28()
{
    B28 b1;
    B28 b2 = b1;
    assert(s28 == "AB");
}


/**********************************/

string s29;

template Templ29 ()
{
    this(int i) { this(0.0); s29 ~= "i"; }
    this(double d) { s29 ~= "d"; }
}

class C29 { mixin Templ29; }
struct S29 { mixin Templ29; }

void test29()
{
    auto r = S29(1);
    assert(s29 == "di");

    r = S29(2.0);
    assert(s29 == "did");

    auto c = new C29(2);
    assert(s29 == "diddi");

    auto c2 = new C29(2.0);
    assert(s29 == "diddid");
}

/**********************************/

struct S30
{
    int x;
    this(T)(T args) { x = args + 1; }
}

void test30()
{
    auto s = S30(3);
    assert(s.x == 4);
}

/**********************************/

struct S31
{
    int x;
    this(T...)(T args) { x = args[0] + 1; }
}

void test31()
{
    auto s = S31(3);
    assert(s.x == 4);
}

/**********************************/

struct S32
{
    static int x;

    this(int i)
    {
        printf("ctor %p(%d)\n", &this, i);
        x += 1;
    }

    this(this)
    {
        printf("postblit %p\n", &this);
        x += 0x10;
    }

    ~this()
    {
        printf("dtor %p\n", &this);
        x += 0x100;
    }
}

S32 foo32()
{
    printf("test1\n");
    return S32(1);
}

S32 bar32()
{
    printf("test1\n");
    S32 f = S32(1);
    printf("test2\n");
    return f;
}

void test32()
{
  {
    S32 s = foo32();
  }
  assert(S32.x == 0x101);

  S32.x = 0;
  {
    S32 s = bar32();
  }
  assert(S32.x == 0x101);
}

/**********************************/

struct S33
{
    static int x;

    this(int i)
    {
        printf("ctor %p(%d)\n", &this, i);
        x += 1;
    }

    this(this)
    {
        printf("postblit %p\n", &this);
        x += 0x10;
    }

    ~this()
    {
        printf("dtor %p\n", &this);
        x += 0x100;
    }
}

struct T33
{
    S33 foo()
    {
        return t;
    }

    S33 t;
}

void test33()
{
    {
        T33 t;
        S33 s = t.foo();
    }
    printf("S.x = %x\n", S33.x);
    assert(S33.x == 0x210);
}

/**********************************/

struct X34 {
    int i;
    this(this) {
        printf("postblit %p\n", &this);
        ++i;
    }

    ~this() {
        printf("dtor %p\n", &this);
    }
}

void test34()
{
    X34[2] xs;
//  xs[0][0] = X34();
    printf("foreach\n");
    for (int j = 0; j < xs.length; j++) { auto x = (j++,j--,xs[j]);
        //foreach(x; xs) {
        //printf("foreach x.i = %d\n", x[0].i);
        //assert(x[0].i == 1);
        printf("foreach x.i = %d\n", x.i);
        assert(x.i == 1);
    }
    printf("loop done\n");
}

/**********************************/

struct X35 {
    __gshared int k;
    int i;
    this(this) {
        printf("postblit %p\n", &this);
        ++i;
    }

    ~this() {
        printf("dtor %p\n", &this);
        k++;
    }
}

void test35()
{
    {
        X35[2] xs;
        printf("foreach\n");
        foreach(ref x; xs) {
            printf("foreach x.i = %d\n", x.i);
            assert(x.i == 0);
        }
        printf("loop done\n");
    }
    assert(X35.k == 2);
}

/**********************************/

struct X36 {
    __gshared int k;
    int i;
    this(this) {
        printf("postblit %p\n", &this);
        ++i;
    }

    ~this() {
        printf("dtor %p\n", &this);
        k++;
    }
}

void test36()
{
    {
        X36[2] xs;
        printf("foreach\n");
        foreach(x; xs) {
            printf("foreach x.i = %d\n", x.i);
            assert(x.i == 1);
        }
        printf("loop done\n");
    }
    assert(X36.k == 4);
}

/**********************************/

struct X37 {
    __gshared int k;
    int i;
    this(this) {
        printf("postblit %p\n", &this);
        ++i;
    }

    ~this() {
        printf("dtor %p\n", &this);
        k++;
    }
}

void test37() {
    {
        X37[2][3] xs;
        printf("foreach\n");
        foreach(ref x; xs) {
            printf("foreach x.i = %d\n", x[0].i);
            assert(x[0].i == 0);
        }
        printf("loop done\n");
    }
  assert(X37.k == 6);
}

/**********************************/

struct S38 {
    __gshared int count;
    __gshared int postblit;

    this(int x) {
        printf("this(%d)\n", x);
        assert(this.x == 0);
        this.x = x;
        count++;
    }
    this(this) {
        printf("this(this) with %d\n", x);
        assert(x == 1 || x == 2);
        count++;
        postblit++;
    }
    ~this() {
        printf("~this(%d)\n", x);
        assert(x == 1 || x == 2);
        x = 0;
        count--;
    }
    int x;
}

S38 foo38() {
    auto s = S38(1);
    return s;
}

S38 bar38() {
    return S38(2);
}

void test38()
{
  {
    auto s1 = foo38();
    assert(S38.count == 1);
    assert(S38.postblit == 0);
  }
  assert(S38.count == 0);
  S38.postblit = 0;

  {
    auto s2 = bar38();
    assert(S38.count == 1);
    assert(S38.postblit == 0);
  }
  assert(S38.count == 0);
}


/**********************************/

struct Foo39
{
    int x;
    this(int v){ x = v + 1; }
    void opAssign(int v){
        x = v + 3;
    }
}

void test39()
{
    int y = 5;
    Foo39 f = y;
    assert(f.x == 6);
    f = y;
    assert(f.x == 8);
//  f = Foo39(y);

}

/**********************************/

bool approxEqual(float a, float b)
{
    return a < b ? b-a < .001 : a-b < .001;
}

struct Point {
    float x = 0, y = 0;
    const bool opEquals(const ref Point rhs)
    {
        return approxEqual(x, rhs.x) && approxEqual(y, rhs.y);
    }
}

struct Rectangle {
   Point leftBottom, rightTop;
}

void test40()
{
   Rectangle a, b;
   assert(a == b);
   a.leftBottom.x = 1e-8;
   assert(a == b);
   a.rightTop.y = 5;
   assert(a != b);
}

/**********************************/

struct S41 {
   this(int) immutable {   }
}

void test41()
{
    auto s = new immutable S41(3);
    //writeln(typeid(typeof(s)));
    static assert(is(typeof(s) == immutable(S41)*));

    auto t = immutable S41(3);
    //writeln(typeid(typeof(t)));
    static assert(is(typeof(t) == immutable(S41)));
}

/**********************************/

class C42 {
   this(int) immutable {
   }
}

void test42()
{
    static assert(!__traits(compiles, new C42(3)));
    //writeln(typeid(typeof(c)));
    //static assert(is(typeof(c) == immutable(C42)));

    auto d = new immutable(C42)(3);
    //writeln(typeid(typeof(d)));
    static assert(is(typeof(d) == immutable(C42)));
}

/**********************************/

struct S43 {
    int i;
    int* p;
//  this(int i, int* t) immutable { this.i = i; p = t;  }
}

void test43()
{
    int i;
    assert(!__traits(compiles, immutable(S43)(3, &i)));
    immutable int j = 4;
    auto s = immutable(S43)(3, &j);
    //writeln(typeid(typeof(s)));
    static assert(is(typeof(s) == immutable(S43)));
}

/**********************************/

struct S44 {
    int i;
    immutable(int)* p;
    this(int i, immutable(int)* t) immutable { this.i = i; this.p = t;  }
}

void test44()
{
    int i;
    assert(!__traits(compiles, immutable(S44)(3, &i)));
    immutable int j = 4;
    auto s = immutable(S44)(3, &j);
    //writeln(typeid(typeof(s)));
    static assert(is(typeof(s) == immutable(S44)));
}

/**********************************/

class C45 {
    C45 next;
    this(int[] data) immutable {
        next = new immutable(C45)(data[1 .. $]);
    }
}

void test45()
{
}

/**********************************/
// 3986

struct SiberianHamster
{
   int rat = 813;
   this(string z) { }
}

void test46()
{
   SiberianHamster basil = "cybil";
   assert(basil.rat == 813);
}

/**********************************/
// 8741

struct Vec8741
{
    this(float x)
    {
        m[0] = x;
        m[1] = 58;
    }
    float[2] m;
    static Vec8741 zzz = Vec8741(7);
}

void test8741()
{
    assert(Vec8741.zzz.m[0] == 7);
    assert(Vec8741.zzz.m[1] == 58);
}

/**********************************/

struct Segfault3984
{
    int a;
    this(int x){
        a = x;
    }
}

void test47()
{
    //static
    assert(Segfault3984(3).a == 3);
}

/**********************************/

void test48()
{
    struct B {
        void foo()  {   }
    }
    B x = B.init;
}

/**********************************/

struct Foo49 {
   int z;
   this(int a){z=a;}
}

void bar49(Foo49 a = Foo49(1))
{
    assert(a.z == 1);
}

void test49()
{
    bar49();
    bar49();
}

/**********************************/

struct aStruct{
    int    m_Int;

    this(int a){
        m_Int = a;
    }
}

class aClass{
    void aFunc(aStruct a = aStruct(44))
    {
        assert(a.m_Int == 44);
    }
}

void test50()
{
    aClass a = new aClass();
    a.aFunc();
    a.aFunc();
}

/**********************************/

int A51_a;

struct A51
{
    ~this() { ++A51_a; }
}

void test51()
{
  A51_a = 0; { while(0) A51 a;                      } assert(A51_a == 0);
  A51_a = 0; { if(0) A51 a;                         } assert(A51_a == 0);
  A51_a = 0; { if(1){} else A51 a;                  } assert(A51_a == 0);
  A51_a = 0; { for(;0;) A51 a;                      } assert(A51_a == 0);
  A51_a = 0; { if (1) { A51 a; }                    } assert(A51_a == 1);
  A51_a = 0; { if (1) A51 a;                        } assert(A51_a == 1);
  A51_a = 0; { if(0) {} else A51 a;                 } assert(A51_a == 1);
  A51_a = 0; { if (0) for(A51 a;;) {}               } assert(A51_a == 0);
  A51_a = 0; { if (0) for(;;) A51 a;                } assert(A51_a == 0);
  A51_a = 0; { do A51 a; while(0);                  } assert(A51_a == 1);
  A51_a = 0; { if (0) while(1) A51 a;               } assert(A51_a == 0);
  A51_a = 0; { try A51 a; catch(Error e) {}         } assert(A51_a == 1);
  A51_a = 0; { if (0) final switch(1) A51 a;        } assert(A51_a == 0); // should fail to build
  A51_a = 0; { if (0) switch(1) { A51 a; default: } } assert(A51_a == 0);
  A51_a = 0; { if (0) switch(1) { default: A51 a; } } assert(A51_a == 0);
  A51_a = 0; { if (1) switch(1) { A51 a; default: } } assert(A51_a == 1); // should be 0, right?
  A51_a = 0; { if (1) switch(1) { default: A51 a; } } assert(A51_a == 1);
//  A51_a = 0; { final switch(0) A51 a;               } assert(A51_a == 0);
  A51_a = 0; { A51 a; with(a) A51 b;                } assert(A51_a == 2);
}

/**********************************/

string s52;

struct A52
{
    int m;
    this(this)
    {
        printf("this(this) %p\n", &this);
        s52 ~= 'a';
    }
    ~this()
    {
        printf("~this() %p\n", &this);
        s52 ~= 'b';
    }
    A52 copy()
    {
        s52 ~= 'c';
        A52 another = this;
        return another;
    }
}

void test52()
{
  {
    A52 a;
    A52 b = a.copy();
    printf("a: %p, b: %p\n", &a, &b);
  }
    printf("s = '%.*s'\n", s52.length, s52.ptr);
    assert(s52 == "cabb");
}

/**********************************/
// 4339

struct A53 {
    invariant() {   }
    ~this() { }
    void opAssign(A53 a) {}
    int blah(A53 a) { return 0; }
}

/**********************************/

struct S54
{
    int x = 1;

    int bar() { return x; }

    this(int i)
    {
        printf("ctor %p(%d)\n", &this, i);
        t ~= "a";
    }

    this(this)
    {
        printf("postblit %p\n", &this);
        t ~= "b";
    }

    ~this()
    {
        printf("dtor %p\n", &this);
        t ~= "c";
    }

    static string t;
}

void bar54(S54 s) { }

S54 abc54() { return S54(1); }

void test54()
{
    {   S54.t = null;
        S54 s = S54(1);
    }
    assert(S54.t == "ac");

    {   S54.t = null;
        S54 s = S54();
    }
    assert(S54.t == "c");

    {   S54.t = null;
        int b = 1 && (bar54(S54(1)), 1);
    }
    assert(S54.t == "ac");

    {   S54.t = null;
        int b = 0 && (bar54(S54(1)), 1);
    }
    assert(S54.t == "");

    {   S54.t = null;
        int b = 0 || (bar54(S54(1)), 1);
    }
    assert(S54.t == "ac");

    {   S54.t = null;
        int b = 1 || (bar54(S54(1)), 1);
    }
    assert(S54.t == "");

    {
    S54.t = null;
    { const S54 s = S54(1); }
        assert(S54.t == "ac");
    }
    {
        S54.t = null;
        abc54();
        assert(S54.t == "ac");
    }
    {
        S54.t = null;
        abc54().x += 1;
        assert(S54.t == "ac");
    }
}

/**********************************/

void test55()
{
    S55 s;
    auto t = s.copy();
    assert(t.count == 1);   // (5)
}

struct S55
{
    int count;
    this(this) { ++count; }
    S55 copy() { return this; }
}

/**********************************/

struct S56
{
    int x = 1;

    int bar() { return x; }

    this(int i)
    {
        printf("ctor %p(%d)\n", &this, i);
        t ~= "a";
    }

    this(this)
    {
        printf("postblit %p\n", &this);
        t ~= "b";
    }

    ~this()
    {
        printf("dtor %p\n", &this);
        t ~= "c";
    }

    static string t;
}

int foo56()
{
    throw new Throwable("hello");
    return 5;
}


void test56()
{
    int i;
    int j;
    try
    {
        j |= 1;
        i = S56(1).x + foo56() + 1;
        j |= 2;
    }
    catch (Throwable o)
    {
        printf("caught\n");
        j |= 4;
    }
    printf("i = %d, j = %d\n", i, j);
    assert(i == 0);
    assert(j == 5);
}

/**********************************/
// 5859

int dtor_cnt = 0;
struct S57
{
    int v;
    this(int n){ v = n; printf("S.ctor v=%d\n", v); }
    ~this(){ ++dtor_cnt; printf("S.dtor v=%d\n", v); }
    bool opCast(T:bool)(){ printf("S.cast v=%d\n", v); return true; }
}
S57 f(int n){ return S57(n); }

void test57()
{
    printf("----\n");
    dtor_cnt = 0;
    if (auto s = S57(10))
    {
        printf("ifbody\n");
    }
    else assert(0);
    assert(dtor_cnt == 1);

    printf("----\n");    //+
    dtor_cnt = 0;
    if (auto s = (S57(1), S57(2), S57(10)))
    {
        assert(dtor_cnt == 2);
        printf("ifbody\n");
    }
    else assert(0);
    assert(dtor_cnt == 3);  // +/

    printf("----\n");
    dtor_cnt = 0;
    try{
        if (auto s = S57(10))
        {
            printf("ifbody\n");
            throw new Exception("test");
        }
        else assert(0);
    }catch (Exception e){}
    assert(dtor_cnt == 1);



    printf("----\n");
    dtor_cnt = 0;
    if (auto s = f(10))
    {
        printf("ifbody\n");
    }
    else assert(0);
    assert(dtor_cnt == 1);

    printf("----\n");    //+
    dtor_cnt = 0;
    if (auto s = (f(1), f(2), f(10)))
    {
        assert(dtor_cnt == 2);
        printf("ifbody\n");
    }
    else assert(0);
    assert(dtor_cnt == 3);  // +/

    printf("----\n");
    dtor_cnt = 0;
    try{
        if (auto s = f(10))
        {
            printf("ifbody\n");
            throw new Exception("test");
        }
        else assert(0);
    }catch (Exception e){}
    assert(dtor_cnt == 1);




    printf("----\n");
    dtor_cnt = 0;
    if (S57(10))
    {
        assert(dtor_cnt == 1);
        printf("ifbody\n");
    }
    else assert(0);

    printf("----\n");
    dtor_cnt = 0;
    if ((S57(1), S57(2), S57(10)))
    {
        assert(dtor_cnt == 3);
        printf("ifbody\n");
    }
    else assert(0);

    printf("----\n");
    dtor_cnt = 0;
    try{
        if (auto s = S57(10))
        {
            printf("ifbody\n");
            throw new Exception("test");
        }
        else assert(0);
    }catch (Exception e){}
    assert(dtor_cnt == 1);



    printf("----\n");
    dtor_cnt = 0;
    if (f(10))
    {
        assert(dtor_cnt == 1);
        printf("ifbody\n");
    }
    else assert(0);

    printf("----\n");
    dtor_cnt = 0;
    if ((f(1), f(2), f(10)))
    {
        assert(dtor_cnt == 3);
        printf("ifbody\n");
    }
    else assert(0);

    printf("----\n");
    dtor_cnt = 0;
    try{
        if (auto s = f(10))
        {
            printf("ifbody\n");
            throw new Exception("test");
        }
        else assert(0);
    }catch (Exception e){}
    assert(dtor_cnt == 1);
}

/**********************************/
// 5574

struct foo5574a
{
    ~this() {}
}
class bar5574a
{
    foo5574a[1] frop;
}

struct foo5574b
{
    this(this){}
}
struct bar5574b
{
    foo5574b[1] frop;
}

/**********************************/
// 5777

int sdtor58 = 0;
S58* ps58;

struct S58
{
    @disable this(this);
    ~this(){ ++sdtor58; }
}

S58 makeS58()
{
    S58 s;
    ps58 = &s;
    return s;
}

void test58()
{
    auto s1 = makeS58();
    assert(ps58 == &s1);
    assert(sdtor58 == 0);
}

/**********************************/
// 6308

struct C59
{
    void oops()
    {
        throw new Throwable("Oops!");
    }

    ~this()
    {
    }
}

void foo59()
{
    C59().oops();
//  auto c = C(); c.oops();
}


void test59()
{
    int i = 0;
    try
        foo59();
    catch (Throwable)
    {   i = 1;
    }
    assert(i == 1);
}

/**********************************/
// 5737

void test5737()
{
    static struct S
    {
        static int destroyed;
        static int copied;

        this(this)
        {
            copied++;
        }

        ~this()
        {
            destroyed++;
        }
    }

    static S s;

    ref S foo()
    {
        return s;
    }

    {
        auto s2 = foo();
    }

    assert(S.copied == 1); // fail, s2 was not copied;
    assert(S.destroyed == 1); // ok, s2 was destroyed
}

/**********************************/
// 6119

void test6119()
{
    int postblit = 0;
    int dtor = 0;

    struct Test
    {
        this(this) { ++postblit; }
        ~this()    { ++dtor; }
    }

    void takesVal(Test x) {}
    ref Test returnsRef(ref Test x) { return x; }

    void f(ref Test x) { takesVal( x ); }

    Test x;

    postblit = dtor = 0;
    takesVal(returnsRef(x));
    assert(postblit == 1);
    assert(dtor == 1);

    postblit = dtor = 0;
    f(x);
    assert(postblit == 1);
    assert(dtor == 1);
}

/**********************************/
// 6364

struct Foo6364
{
    int state = 1;

    ~this()
    {
        state = 0;
    }
}

void testfoo6364()
{
    static Foo6364 foo;
    printf("%d\n", foo.state);
    assert(foo.state == 1);
}

void test6364()
{
    testfoo6364();
    testfoo6364();
}

/**********************************/
// 6499

struct S6499
{
    string m = "<not set>";

    this(string s)
    {
        m = s;
        printf("Constructor - %.*s\n", m.length, m.ptr);
        if (m == "foo") { ++sdtor; assert(sdtor == 1); }
        if (m == "bar") { ++sdtor; assert(sdtor == 2); }
    }
    this(this)
    {
        printf("Postblit    - %.*s\n", m.length, m.ptr);
        assert(0);
    }
    ~this()
    {
        printf("Destructor  - %.*s\n", m.length, m.ptr);
        if (m == "bar") { assert(sdtor == 2); --sdtor; }
        if (m == "foo") { assert(sdtor == 1); --sdtor; }
    }
    S6499 bar()     { return S6499("bar"); }
    S6499 baz()()   { return S6499("baz"); }
}

void test6499()
{
    S6499 foo() { return S6499("foo"); }

    {
        sdtor = 0;
        scope(exit) assert(sdtor == 0);
        foo().bar();
    }
    {
        sdtor = 0;
        scope(exit) assert(sdtor == 0);
        foo().baz();
    }
}

/**********************************/

template isImplicitlyConvertible(From, To)
{
    enum bool isImplicitlyConvertible = is(typeof({
                        void fun(ref From v) {
                            void gun(To) {}
                            gun(v);
                        }
                    }()));
}

void test60()
{
    static struct X1
    {
        void* ptr;
        this(this){}
    }
    static struct S1
    {
        X1 x;
    }

    static struct X2
    {
        int ptr;
        this(this){}
    }
    static struct S2
    {
        X2 x;
    }

    {
              S1  ms;
              S1  ms2 = ms; // mutable to mutable
        const(S1) cs2 = ms; // mutable to const                         // NG -> OK
    }
    {
        const(S1) cs;
        static assert(!__traits(compiles,{                              // NG -> OK
              S1 ms2 = cs;  // field has reference, then const to mutable is invalid
        }));
        const(S1) cs2 = cs; // const to const                           // NG -> OK
    }
    static assert( isImplicitlyConvertible!(      S1 ,       S1 ) );
    static assert( isImplicitlyConvertible!(      S1 , const(S1)) );    // NG -> OK
    static assert(!isImplicitlyConvertible!(const(S1),       S1 ) );
    static assert( isImplicitlyConvertible!(const(S1), const(S1)) );    // NG -> OK


    {
              S2  ms;
              S2  ms2 = ms; // mutable to mutable
        const(S2) cs2 = ms; // mutable to const                         // NG -> OK
    }
    {
        const(S2) cs;
              S2  ms2 = cs; // all fields are value, then const to mutable is OK
        const(S2) cs2 = cs; // const to const                           // NG -> OK
    }

    static assert( isImplicitlyConvertible!(      S2 ,       S2 ) );
    static assert( isImplicitlyConvertible!(      S2 , const(S2)) );    // NG -> OK
    static assert( isImplicitlyConvertible!(const(S2),       S2 ) );
    static assert( isImplicitlyConvertible!(const(S2), const(S2)) );    // NG -> OK
}

/**********************************/
// 4316

struct A4316
{
    this(this) @safe { }
}

@safe void test4316()
{
    A4316 a;
    auto b = a; // Error: safe function 'main' cannot call system function'__cpctor'
}

/**********************************/

struct F6177
{
    ~this()    {}
}

struct G6177
{
    this(F6177[] p...) {}
}

void test6177()
{
    F6177 c;
    auto g = G6177(c);
}


/**********************************/
// 6470

struct S6470
{
    static int spblit;

    this(this){ ++spblit; }
}

void test6470()
{
    S6470[] a1;
    S6470[] a2;
    a1.length = 3;
    a2.length = 3;
    a1[] = a2[];
    assert(S6470.spblit == 3);

    S6470 s;

    S6470[] a3;
    a3.length = 3;
    a3 = [s, s, s];
    assert(S6470.spblit == 6);

    void func(S6470[] a){}
    func([s, s, s]);
    assert(S6470.spblit == 9);
}

/**********************************/
// 6636

struct S6636
{
    ~this()
    {
        ++sdtor;
    }
}

void func6636(S6636[3] sa) {}

void test6636()
{
    sdtor = 0;

    S6636[3] sa;
    func6636(sa);
    assert(sdtor == 3);
}

/**********************************/
// 6637

struct S6637
{
    static int spblit;

    this(this){ ++spblit; }
}

void test6637()
{
    void func(S6637[3] sa){}

    S6637[3] sa;
    func(sa);
    assert(S6637.spblit == 3);
}

/**********************************/
// 7353

struct S7353
{
    static uint ci = 0;
    uint i;

    this(int x) { i = ci++; /*writeln("new: ", i);*/ }
    this(this)  { i = ci++; /*writeln("copy ", i);*/ }
    ~this()     {           /*writeln("del ", i);*/ }

    S7353 save1() // produces 2 copies in total
    {
        S7353 s = this;
        return s;
    }
    auto save2() // produces 3 copies in total
    {
        S7353 s = this;
        return s;
        pragma(msg, typeof(return));
    }
}
void test7353()
{
    {
        auto s = S7353(1), t = S7353(1);
        t = s.save1();
        assert(S7353.ci == 3);
    }
    S7353.ci = 0; //writeln("-");
    {
        auto s = S7353(1), t = S7353(1);
        t = s.save2();
        assert(S7353.ci == 3);
    }
}

/**********************************/
// 8036

struct S8036a
{
    ~this() {}
}
struct S8036b // or class
{
    S8036a[0] s;
}

/**********************************/

struct S61
{
    this(long length)
    {
        this.length = length;
    }

    long length;
}


const(S61) copy(const S61 s)
{
    return s;
}


void test61()
{
    S61 t = S61(42);
    const S61 u = t;

    assert(t == u);
    assert(copy(t) == u);
    assert(t == copy(u));
}

/**********************************/
// 7506

void test7506()
{
    static struct S
    {
        static uint ci = 0;
        static uint di = 0;
        uint i;

        this(int x) { i = ci++; /*writeln("new: ", i);*/ }
        this(this)  { i = ci++; /*writeln("copy ", i);*/ }
        ~this()     { ++di;     /*writeln("del: ", i);*/ }

        S save3()
        {
            return this;
        }
    }

    {
        auto s = S(1), t = S(1);
        assert(S.ci == 2);
        t = s.save3();
        assert(S.ci == 3);  // line 23
    }
    assert(S.di == 3);
}

/**********************************/
// 7530

void test7530()
{
    static struct S
    {
        int val;

        this(int n) { val = n; }
        this(this) { val *= 3; }
    }

    S[] sa = new S[](1);
    sa[0].val = 1;
    S foo()
    {
        return sa[0];
    }
    auto s = foo();
    assert(s.val == 3);
}

/**********************************/

struct S62
{
    this(int length)
    {
        _length = length;
    }

    int opBinary(string op)(in S62 rhs) const
        if(op == "-")
    {
        return this.length - rhs.length;
    }

    @property int length() const
    {
        return _length;
    }

    invariant()
    {
        assert(_length == 1);
    }

    int _length  = 1;
}


void test62()
{
    immutable result = S62.init - S62.init;
}

/**********************************/
// 7579

void test7579a()
{
    static struct S
    {
        // postblit can also have no body because isn't called
        @disable this(this) { assert(0); }
    }

    @property S fs() { return S(); }
    @property S[3] fsa() { return [S(), S(), S()]; }

    S s0;
    S s1 = S();
    static assert(!__traits(compiles, { S s2 = s1; }));         // OK
    S s2 = fs;
    static assert(!__traits(compiles, { s2 = s1; }));           // OK

    // static array
    S[3] sa0;
    S[3] sa1 = [S(), S(), S()];
    static assert(!__traits(compiles, { S[3] sa2 = sa1; }));    // fixed
    S[3] sa2 = fsa;
    static assert(!__traits(compiles, { sa2 = sa1; }));         // fixed
    sa2 = [S(), S(), S()];
    sa2 = fsa;

    S[] da1 = new S[3];
    S[] da2 = new S[3];
    static assert(!__traits(compiles, { da2[] = da1[]; }));     // fixed

    // concatenation and appending
    static assert(!__traits(compiles, { da1 ~= s1; }));         // fixed
    static assert(!__traits(compiles, { da1 ~= S(); }));
    static assert(!__traits(compiles, { da1 ~= fsa; }));
    static assert(!__traits(compiles, { da1 ~= fsa[]; }));
    static assert(!__traits(compiles, { da1 = da1 ~ s1; }));    // fixed
    static assert(!__traits(compiles, { da1 = s1 ~ da1; }));    // fixed
    static assert(!__traits(compiles, { da1 = da1 ~ S(); }));
    static assert(!__traits(compiles, { da1 = da1 ~ fsa; }));
    static assert(!__traits(compiles, { da1 = da1 ~ da; }));
}

void test7579b()
{
    static struct S
    {
        // postblit asserts in runtime
        this(this) { assert(0); }
    }

    @property S fs() { return S(); }
    @property S[3] fsa() { return [S(), S(), S()]; }

    S s0;
    S s1 = S();
    S s2 = fs;

    // static array
    S[3] sa0;
    S[3] sa1 = [S(), S(), S()];
    S[3] sa2 = fsa;
    sa2 = [S(), S(), S()];
    sa2 = fsa;

    S[] da1 = new S[3];
    S[] da2 = new S[3];

    // concatenation and appending always run postblits
}

/**********************************/
// 8335

struct S8335
{
    static int postblit;

    int i;
    this(this) { ++postblit; }
}

void f8335(ref S8335[3] arr)
{
    arr[0].i = 7;
}

void g8335(lazy S8335[3] arr)
{
    assert(S8335.postblit == 0);
    auto x = arr;
}

void h8335(lazy S8335 s)
{
    assert(S8335.postblit == 0);
    auto x = s;
    assert(S8335.postblit == 1);
}

void test8335()
{
    S8335[3] arr;
    f8335(arr);
    assert(S8335.postblit == 0);
    assert(arr[0].i == 7);

    g8335(arr);
    assert(S8335.postblit == 3);

    S8335.postblit = 0;
    S8335 s;
    h8335(s);
    assert(S8335.postblit == 1);
}

/**********************************/
// 8356

void test8356()
{
    static struct S
    {
        @disable this(this) { assert(0); }
    }

    S s;
    S[3] sa;

  static assert(!__traits(compiles, {
    S fs() { return s; }
  }));

  static assert(!__traits(compiles, {
    S[3] fsa() { return sa; }
  }));
}

/**********************************/
// 8475

T func8475(T)(T x) @safe pure
{
    return T();
}

template X8475(bool something)
{
    struct XY
    {
        this(this) @safe pure {}
        void func(XY x) @safe pure
        {
            XY y = x; //Error: see below
            func8475(x);
            func8475(y);
        }
    }
}

alias X8475!(true).XY Xtrue;

/**********************************/

struct Foo9320 {
    real x;

    this(real x) {
        this.x = x;
    }

    Foo9320 opBinary(string op)(Foo9320 other) {
        return Foo9320(mixin("x" ~ op ~ "other.x"));
    }
}

Foo9320 test9320(Foo9320 a, Foo9320 b, Foo9320 c) {
    return (a + b) / (a * b) - c;
}

/**********************************/
// 9386

struct Test9386
{
    string name;
    static string op;

    this(string name)
    {
        this.name = name;
        printf("Created %.*s...\n", name.length, name.ptr);
        op ~= "a";
    }

    this(this)
    {
        printf("Copied %.*s...\n", name.length, name.ptr);
        op ~= "b";
    }

    ~this()
    {
        printf("Deleted %.*s\n", name.length, name.ptr);
        op ~= "c";
    }
}

void test9386()
{
    {
        Test9386.op = null;

        Test9386[] tests =
            [ Test9386("one"),
              Test9386("two"),
              Test9386("three"),
              Test9386("four") ];

        assert(Test9386.op == "aaaa");
        Test9386.op = null;

        printf("----\n");
        foreach (Test9386 test; tests)
        {
            printf("\tForeach %.*s\n", test.name.length, test.name.ptr);
            Test9386.op ~= "x";
        }

        assert(Test9386.op == "bxcbxcbxcbxc");
        Test9386.op = null;

        printf("----\n");
        foreach (ref Test9386 test; tests)
        {
            printf("\tForeach %.*s\n", test.name.length, test.name.ptr);
            Test9386.op ~= "x";
        }
        assert(Test9386.op == "xxxx");
    }
    printf("====\n");
    {
        Test9386.op = null;

        Test9386[Test9386] tests =
            [ Test9386("1") : Test9386("one"),
              Test9386("2") : Test9386("two"),
              Test9386("3") : Test9386("three"),
              Test9386("4") : Test9386("four") ];

        assert(Test9386.op == "aaaaaaaa");
        Test9386.op = null;

        printf("----\n");
        foreach (Test9386 k, Test9386 v; tests)
        {
            printf("\tForeach %.*s : %.*s\n", k.name.length, k.name.ptr,
                                              v.name.length, v.name.ptr);
            Test9386.op ~= "x";
        }

        assert(Test9386.op == "bbxccbbxccbbxccbbxcc");
        Test9386.op = null;

        printf("----\n");
        foreach (Test9386 k, ref Test9386 v; tests)
        {
            printf("\tForeach %.*s : %.*s\n", k.name.length, k.name.ptr,
                                              v.name.length, v.name.ptr);
            Test9386.op ~= "x";
        }
        assert(Test9386.op == "bxcbxcbxcbxc");
    }
}

/**********************************/
// 9441

auto x9441 = X9441(0.123);

struct X9441
{
    int a;
    this(double x) { a = cast(int)(x * 100); }
}

void test9441()
{
    assert(x9441.a == 12);
}

/**********************************/

struct Payload
{
    size_t _capacity; //Comment me
    int[] _pay;       //Comment me

    size_t insertBack(Data d)
    {
        immutable newLen   = _pay.length + 3;
        _pay.length = newLen;
        _pay = _pay[0 .. newLen]; //Comment me
        return 3;
    }
}

struct Impl
{
    Payload _payload;
    size_t _count;
}

struct Data
{
    Impl* _store;

    this(int i)
    {
        _store = new Impl;
        _store._payload = Payload.init;
    }

    ~this()
    {
        printf("%d\n", _store._count);
        --_store._count;
    }
}


void test9720()
{
    auto a = Data(1);
    auto b = Data(1);
    a._store._payload.insertBack(b); //Fails
}

/**********************************/
// 9899

struct S9899
{
    @safe pure nothrow ~this() {}
}

struct MemberS9899
{
    S9899 s;
}

void test9899() @safe pure nothrow
{
    MemberS9899 s; // 11
}

/**********************************/
// 9907

void test9907()
{
    static struct SX(bool hasCtor, bool hasDtor)
    {
        int i;
        static size_t assign;
        static size_t dtor;

        static if (hasCtor)
        {
            this(int i) { this.i = i; }
        }

        void opAssign(SX rhs)
        {
            printf("%08X(%d) from Rvalue %08X(%d)\n", &this.i, this.i, &rhs.i, rhs.i);
            ++assign;
        }

        void opAssign(ref SX rhs)
        {
            printf("%08X(%d) from Lvalue %08X(%d)\n", &this.i, this.i, &rhs.i, rhs.i);
            assert(0);
        }

        static if (hasDtor)
        {
            ~this()
            {
                printf("destroying %08X(%d)\n", &this.i, this.i);
                ++dtor;
            }
        }
    }

    S test(S)(int i)
    {
        return S(i);
    }

    foreach (hasCtor; TypeTuple!(false, true))
    foreach (hasDtor; TypeTuple!(false, true))
    {
        alias S = SX!(hasCtor, hasDtor);
        alias test!S foo;

        printf("----\n");
        auto s = S(1);

        // Assignment from two kinds of rvalues
        assert(S.assign == 0);
        s = foo(2);
        static if (hasDtor) assert(S.dtor == 1);
        assert(S.assign == 1);
        s = S(3);
        assert(S.assign == 2);
        static if (hasDtor) assert(S.dtor == 2);
    }
    printf("----\n");
}

/**********************************/
// 9994

void test9994()
{
    static struct S
    {
        static int dtor;
        ~this() { ++dtor; }
    }

    S s;
    static assert( __traits(compiles, s.opAssign(s)));
    static assert(!__traits(compiles, s.__postblit()));

    assert(S.dtor == 0);
    s = s;
    assert(S.dtor == 1);
}

/**********************************/

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
    test15();
    test16();
    test17();
    test18();
    test19();
    test20();
    test21();
    test22();
    test23();
    test24();
    test25();
    test26();
    test27();
    test28();
    test29();
    test30();
    test31();
    test32();
    test33();
    test34();
    test35();
    test36();
    test37();
    test38();
    test39();
    test40();
    test41();
    test42();
    test43();
    test44();
    test45();
    test46();
    test47();
    test48();
    test49();
    test50();
    test51();
    test52();

    test54();
    test55();
    test56();
    test57();
    test58();
    test59();
    test5737();
    test6119();
    test8741();
    test6364();
    test6499();
    test60();
    test4316();
    test6177();
    test6470();
    test6636();
    test6637();
    test7353();
    test61();
    test7506();
    test7530();
    test62();
    test7579a();
    test7579b();
    test8335();
    test8356();
    test9386();
    test9441();
    test9720();
    test9899();
    test9907();
    test9994();

    printf("Success\n");
    return 0;
}
