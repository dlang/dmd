
import std.c.stdio;

class C { }

int ctfe() { return 3; }

/************************************/

void showf(string f)
{
    printf("%.*s\n", f.length, f.ptr);
}

/************************************/

void test1()
{
    const int* p;
    const(int)* cp;
    cp = p;
}

/************************************/

void test2()
{
    const int i = 3;
    const(int) j = 0;
    int k;
//    j = i;
    k = i;
    k = j;
//    assert(k == 3);
}

/************************************/

void test3()
{
    char[3] p;
    const(char)[] q;

    q = p;
}

/************************************/

void test4()
{
    char[] p;
    const(char)[] q;

    q = p;
}

/************************************/

void test5()
{
    const(int**)* p;
    const(int)*** cp;
    p = cp;
}

/************************************/

void test6()
{
    const(int***)[] p;
    const(int)***[] cp;
    p = cp;
}

/************************************/

class C8 { }

void foo8(const char[] s, const C8 c, const int x)
{
}

void test8()
{
    auto p = &foo8;
    showf(p.mangleof);
    assert(typeof(p).mangleof == "PFxAaxC9testconst2C8xiZv");
    assert(p.mangleof == "_D9testconst5test8FZv1pPFxAaxC9testconst2C8xiZv");
}

/************************************/

void test9()
{
    int [ const (char[]) ] aa;
    int [ char[] ] ab;
    int [ const char[] ] ac;

    aa["hello"] = 3;
    ab["hello"] = 3;
    ac["hello"] = 3;
}

/************************************/

void test10()
{
    const(int) x = 3;
    auto y = x;
    //y++;
    assert(is(typeof(y) == const(int)));
}

/************************************/

void foo11(in char[] a1)
{
    char[3] c;
    char[] a2 = c[];
    a2[0..2] = a1;
    a2[0..2] = 'c';

    const char b = 'b';
    a2[0..2] = b;
}

void test11()
{
}

/************************************/

void foo12(const char[] a1)
{
}

void test12()
{
    foo12("hello");
}

/************************************/

immutable char[16] hexdigits1 = "0123456789ABCDE1";
immutable char[  ] hexdigits2 = "0123456789ABCDE2";

const char[16] hexdigits3 = "0123456789ABCDE3";
const char[  ] hexdigits4 = "0123456789ABCDE4";

void test13()
{
}

/************************************/

void test14()
{
    string s;
    s = s ~ "hello";
}

/************************************/

class Foo15
{
    const string xxxx;

    this(immutable char[] aaa)
    {
        this.xxxx = aaa;
    }
}

void test15()
{
}

/************************************/

void test16()
{
    auto a = "abc";
    immutable char[3] b = "abc";
    const char[3] c = "abc";
}

/************************************/

void test17()
{
    const(char)[3][] a = (["abc", "def"]);

    assert(a[0] == "abc");
    assert(a[1] == "def");
}

/************************************/

class C18
{
    const(char)[] foo() { return "abc"; }
}

class D18 : C18
{
    override char[] foo() { return null; }
}

void test18()
{
}

/************************************/

void test19()
{
    char[] s;
    if (s == "abc")
        s = null;
    if (s < "abc")
        s = null;
    if (s is "abc")
        s = null;
}

/************************************/

void test20()
{
    string p;
    immutable char[] q;

    p = p ~ q;
    p ~= q;
}

/************************************/

void test21()
{
    string s;
    char[] p;
    p = s.dup;
}

/************************************/

void fill22(const(char)[] s)
{
}

void test22()
{
}

/************************************/


struct S23
{
    int x;
    int* p;
}


void foo23(const(S23) s, const(int) i)
{
    immutable int j = 3;
//    j = 4;
//    i = 4;
//    s.x = 3;
//    *s.p = 4;
}

void test23()
{
}

/************************************/

void test24()
{
    wchar[] r;

    r ~= "\000";
}

/************************************/

void test25()
{
    char* p;
    if (p == cast(const(char)*)"abc")
    {}
}

/************************************/

void test26()
{
    struct S
    {
        char[3] a;
    }

    static S s = { "abc" };
}

/************************************/

class C27
{
    int x;

    void foo() { x = 3; }
}

void test27()
{
    C27 d = new C27;
    d.foo();
}

/************************************/

class C28
{
    int x;

    void foo() immutable { }
}

void test28()
{
    immutable(C28) d = cast(immutable)new C28;
    d.foo();
}

/************************************/

struct S29 { }

int foo29(const(S29)* s)
{
    S29 s2;
    return *s == s2;
}

void test29()
{
}

/************************************/

struct S30
{
    int x;

    void foo() { x = 3; }
    void bar() const
    {   //x = 4;
        //this.x = 5;
    }
}

class C30
{
    int x;

    void foo() { x = 3; }
    void bar() const
    {   //x = 4;
        //this.x = 5;
    }
}

void test30()
{   S30 s;

    s.foo();
    s.bar();

    S30 t;
    //t.foo();
    t.bar();

    C30 c = new C30;

    c.foo();
    c.bar();

    C30 d = new C30;
    d.foo();
    d.bar();
}


/************************************/

class Foo31
{
  int x;

  immutable immutable(int)* geti()
  {
    return &x;
  }

  const const(int)* getc()
  {
    return &x;
  }
}

void test31()
{
}

/************************************/

int bar32;

struct Foo32
{
    int func() immutable
    {
        return bar32;
    }
}

void test32()
{
    immutable(Foo32) foo;
    printf("%d", foo.func());
    printf("%d", foo.func());
}

/************************************/

void test33()
{
    string d = "a"  ~  "b"  ~  (1?"a":"");
    assert(d == "aba");
}

/************************************/

struct S34
{
   int value;
}

const S34 s34 = { 5 };

const S34 t34 = s34;
const S34 u34 = s34;

void test34()
{
    assert(u34.value == 5);
}

/************************************/

const int i35 = 20;

template Foo35(alias bar)
{
}

alias Foo35!(i35) foo35;

void test35()
{
}

/************************************/

immutable char[10] digits    = "0123456789";  /// 0..9
immutable char[]  octdigits = digits[0 .. 8]; //// 0..7

void test36()
{
}

/************************************/

void test37()
{
    int i = 3;
    const int x = i;
    i++;
    assert(x == 3);
}

/************************************/

void test38()
{
    static const string s = "hello"[1..$];
    assert(s == "ello");
}

/************************************/

static const int x39;
const int y39;

static this()
{
    x39 = 3;
    y39 = 4;
}

void test39()
{
    const int i;
    assert(x39 == 3);
    assert(y39 == 4);
    const p = &x39;
//    assert(*p == 3);
}

/************************************/

struct S40
{
    int a;
    const int b = 3;    // shouldn't be allocated
}

void test40()
{
    assert(S40.sizeof == 4);
    assert(S40.b == 3);
}

/************************************/

struct S41
{
    int a;
    const int b;
    static const int c = ctfe() + 1;
}

void test41()
{
    assert(S41.sizeof == 8);
    S41 s;
    assert(s.b == 0);
    assert(S41.c == 4);

    const(int)*p;
    p = &s.b;
    assert(*p == 0);
    p = &s.c;
    assert(*p == 4);
}

/************************************/

class C42
{
    int a = ctfe() - 2;
    const int b;
    const int c = ctfe();
    static const int d;
    static const int e = ctfe() + 2;

    static this()
    {
        d = 4;
    }

    this()
    {
        b = 2;
    }
}

void test42()
{
    printf("%d\n", C42.classinfo.init.length);
    assert(C42.classinfo.init.length == 8 + (void*).sizeof + (void*).sizeof);
    C42 c = new C42;
    assert(c.a == 1);
    assert(c.b == 2);
    assert(c.c == 3);
    assert(c.d == 4);
    assert(c.e == 5);

    const(int)*p;
    p = &c.b;
    assert(*p == 2);
//    p = &c.c;
//    assert(*p == 3);
    p = &c.d;
    assert(*p == 4);
    p = &c.e;
    assert(*p == 5);
}

/************************************/

template Foo43(T)
{
    alias T Foo43;
}

void test43()
{
  {
    int x;
    alias Foo43!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo43!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == const(int)));
    assert(is(f == const(int)));
  }

  {
    immutable int x;
    alias Foo43!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == immutable(int)));
    assert(is(f == immutable(int)));
  }
}

/************************************/

template Foo44(T:T)
{
    alias T Foo44;
}

void test44()
{
  {
    int x;
    alias Foo44!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo44!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == const(int)));
    assert(is(f == const(int)));
  }

  {
    immutable int x;
    alias Foo44!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == immutable(int)));
    assert(is(f == immutable(int)));
  }
}

/************************************/

template Foo45(T:const(T))
{
    alias T Foo45;
}

void test45()
{
  {
    int x;
    alias Foo45!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo45!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == const(int)));
    assert(is(f == int));
  }

  {
    immutable int x;
    alias Foo45!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == immutable(int)));
    assert(is(f == int));
  }
}

/************************************/

template Foo46(T:immutable(T))
{
    alias T Foo46;
}

void test46()
{
  {
    immutable int x;
    alias Foo46!(typeof(x)) f;
    showf(typeid(f).toString());
    assert(is(typeof(x) == immutable(int)));
    assert(is(f == int));
  }
}

/************************************/

template Foo47(T:T)            { const int Foo47 = 2; }
template Foo47(T:const(T))     { const int Foo47 = 3; }
template Foo47(T:immutable(T)) { const int Foo47 = 4; }

void test47()
{
    int x2;
    const int x3;
    immutable int x4;

    printf("%d\n", Foo47!(typeof(x2)));
    printf("%d\n", Foo47!(typeof(x3)));
    printf("%d\n", Foo47!(typeof(x4)));

    assert(Foo47!(typeof(x2)) == 2);
    assert(Foo47!(typeof(x3)) == 3);
    assert(Foo47!(typeof(x4)) == 4);
}

/************************************/

int foo48(T)(const(T) t) { return 3; }

void test48()
{
    const int x = 4;
    assert(foo48(x) == 3);
}

/************************************/

void foo49(T)(T[] t)
{
    showf(typeid(typeof(t)).toString());
    assert(is(T == immutable(char)));
}

void bar49(T)(const T t)
{
    showf(typeid(T).toString());
    assert(is(T == const(int)) || is(T == immutable(int)) || is(T == int));
}

void test49()
{
    string s;
    foo49(s);
    foo49("hello");

    const int c = 1;
    bar49(c);

    immutable int i = 1;
    bar49(i);

    bar49(1);
}

/************************************/

void foo50(T)(T t)
{
    showf(typeid(typeof(t)).toString());
    assert(is(T == C));
}

void baz50(T)(T t)
{
    showf(typeid(typeof(t)).toString());
    assert(is(T == const(C)));
}

void bar50(T)(const T t)
{
    showf(typeid(T).toString());
    showf(typeid(typeof(t)).toString());
    assert(is(T == C));
    assert(is(typeof(t) == const(C)));
}

void abc50(T)(const T t)
{
    showf(typeid(T).toString());
    showf(typeid(typeof(t)).toString());
    assert(is(T == const(C)));
    assert(is(typeof(t) == const(C)));
}

void test50()
{
    C c = new C;
    const(C) d = new C;

    foo50(c);
    baz50(d);

    bar50(c);
    abc50(d);
}

/************************************/

void test51()
{
    const(C) d = new C;
    //d = new C;
}

/************************************/

template isStaticArray(T)
{
    const bool isStaticArray = false;
}

template isStaticArray(T : T[N], size_t N)
{
    const bool isStaticArray = true;
}

template isDynamicArray(T, U = void)
{
    static const isDynamicArray = false;
}

template isDynamicArray(T : U[], U)
{
  static const isDynamicArray = !isStaticArray!(T);
}

void test52()
{
    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);

    showf(typeid(typeof(aa.values)).toString());
    static assert(isDynamicArray!(typeof(aa.values)));
}

/************************************/

void foo53(string n) { }

void read53(in string name)
{
    foo53(name);
}

void test53()
{
    read53("hello");
}

/************************************/

void bar54(const(wchar)[] s) { }

void test54()
{
    const(wchar)[] fmt;
    bar54("Orphan format specifier: %" ~ fmt);
}

/************************************/

struct S55
{
    int foo() { return 1; }
    int foo() const { return 2; }
    int foo() immutable { return 3; }
}

void test55()
{
    S55 s1;
    auto i = s1.foo();
    assert(i == 1);

    const S55 s2;
    i = s2.foo();
    assert(i == 2);

    immutable S55 s3;
    i = s3.foo();
    assert(i == 3);
}

/************************************/

const struct S56 { int a; }

void test56()
{
    S56 s;
    S56 t;
    printf("S56.sizeof = %d\n", S56.sizeof);
    //t = s;
}

/************************************/

struct S57
{
    const void foo(this T)(int i)
    {
        showf(typeid(T).toString());
        if (i == 1)
            assert(is(T == const));
        if (i == 2)
            assert(!is(T == const));
        if (i == 3)
            assert(is(T == immutable));
    }
}

void test57()
{
    const(S57) s;
    (&s).foo(1);
    S57 s2;
    s2.foo(2);
    immutable(S57) s3;
    s3.foo(3);
}

/************************************/

class C58
{
    const(C58) c;
    const C58 y;

    this()
    {
        y = null;
        c = null;
    }

    const void foo()
    {
        //c = null; // should fail
    }

    void bar()
    {
        //c = null;
    }
}

void test58()
{
}

/************************************/

class A59
{
    int[] a;
    this() { a.length = 1; }

    int* ptr() { return a.ptr; }
    const const(int)* ptr() { return a.ptr; }
    immutable immutable(int)* ptr() { return a.ptr; }
}

void test59()
{
    auto a = new A59;
    const b = cast(const)new A59;
    immutable c = cast(immutable)new A59;
}

/************************************/

int foo60(int i) { return 1; }
int foo60(const int i) { return 2; }
int foo60(immutable int i) { return 3; }

void test60()
{
    int i;
    const int j;
    immutable int k;

    assert(foo60(i) == 1);
    assert(foo60(j) == 2);
    assert(foo60(k) == 3);
}

/************************************/

void foo61(T)(T arg)
{
    alias const(T) CT;
    assert(is(const(int) == CT));
    //writeln(typeid(const(T)));
    //writeln(typeid(CT));
}

void test61()
{
    int x = 42;
    foo61(x);
}

/************************************/

class Foo62(T) { }

void test62()
{
    const(Foo62!(int)) f = new Foo62!(int);
    assert(is(typeof(f) == const(Foo62!(int))));
}

/************************************/

struct S63
{
    int x;
}

void foo63(const ref S63 scheme)
{
    //scheme.x = 3;
}

void test63()
{
        S63 scheme;
        foo63(scheme);
}

/************************************/

struct S64
{
    int a;
    long b;
}

void test64()
{
    S64 s1 = S64(2,3);
    const s2 = S64(2,3);
    immutable S64 s3 = S64(2,3);

    s1 = s1;
    s1 = s2;
    s1 = s3;
}

/************************************/

struct S65
{
    int a;
    long b;
    char *p;
}

void test65()
{   char c;
    S65 s1 = S65(2,3);
    const s2 = S65(2,3);
    immutable S65 s3 = S65(2,3);

    S65 t1 = S65(2,3,null);
    const t2 = S65(2,3,null);
    immutable S65 t3 = S65(2,3,null);
}

/************************************/

struct S66
{
    int a;
    long b;
}

void test66()
{   char c;
    S66 s1 = S66(2,3);
    const s2 = S66(2,3);
    immutable S66 s3 = S66(2,3);

    S66 t1 = s1;
    S66 t2 = s2;
    S66 t3 = s3;

    const(S66) u1 = s1;
    const(S66) u2 = s2;
    const(S66) u3 = s3;

    immutable(S66) v1 = s1;
    immutable(S66) v2 = s2;
    immutable(S66) v3 = s3;
}

/************************************/

struct Foo68
{
    int z;
    immutable int x;
    int y;
}

void test68()
{
    Foo68 bar;
    bar.y = 2;
}

/************************************/

class C69 {}
struct S69 {}

void test69()
{
        immutable(S69)* si;
        S69* sm;
        bool a = si is sm;

        immutable(C69) ci;
        const(C69) cm;
        bool b = ci is cm;
}

/************************************/

struct S70
{
  int i;
}

void test70()
{
  S70 s;
  const(S70) cs = s;
  S70 s1 = cs;
  S70 s2 = cast(S70)cs;
}

/************************************/

void test72()
{
    int a;
    const int b;
    enum { int c = 0 };
    immutable int d = 0;

    assert(__traits(isSame, a, a));
    assert(__traits(isSame, b, b));
    assert(__traits(isSame, c, c));
    assert(__traits(isSame, d, d));
}

/************************************/

void a73(const int [] data...)
{
    a73(1);
}

void test73()
{
}

/************************************/

struct S74 { int x; }

const S74 s_const = {0};

S74 s_mutable = s_const;

void test74()
{
}

/************************************/

struct A75 { int x; }
struct B75 { A75 s1; }

const A75 s1_const = {0};
const B75 s2_const = {s1_const};

void test75()
{
}

/************************************/

void test76()
{
    int[int] array;
    const(int[int]) a = array;
}

/************************************/

void test77()
{
    int[][] intArrayArray;
    int[][][] intArrayArrayArray;

//    const(int)[][] f1 = intArrayArray;
    const(int[])[] f2 = intArrayArray;

//    const(int)[][][] g1 = intArrayArrayArray;
//    const(int[])[][] g2 = intArrayArrayArray;
    const(int[][])[] g3 = intArrayArrayArray;
}

/************************************/

void foo78(T)(const(T)[] arg1, const(T)[] arg2) { }

void test78()
{
    foo78("hello", "world".dup);
    foo78("hello", "world");
    foo78("hello".dup, "world".dup);
    foo78(cast(const)"hello", cast(const)"world");
}

/************************************/

const bool[string] stopWords79;

static this()
{
    stopWords79 = [ "a"[]:1 ];
}

void test79()
{
    "abc" in stopWords79;
}

/************************************/

inout(int) test80(inout(int) _ = 0)
{
    char x;
    inout(char) y = x;

    const(char)[] c;
    immutable(char)[] i;
    shared(char)[] s;
    const(shared(char))[] sc;
    inout(char)[] w;
    inout(shared(char))[] sw;

    c = c;
    c = i;
    static assert(!__traits(compiles, c = s));
    static assert(!__traits(compiles, c = sc));
    c = w;
    static assert(!__traits(compiles, c = sw));

    static assert(!__traits(compiles, i = c));
    i = i;
    static assert(!__traits(compiles, i = s));
    static assert(!__traits(compiles, i = sc));
    static assert(!__traits(compiles, i = w));
    static assert(!__traits(compiles, i = sw));

    static assert(!__traits(compiles, s = c));
    static assert(!__traits(compiles, s = i));
    s = s;
    static assert(!__traits(compiles, s = sc));
    static assert(!__traits(compiles, s = w));
    static assert(!__traits(compiles, s = sw));

    static assert(!__traits(compiles, sc = c));
    sc = i;
    sc = s;
    sc = sc;
    static assert(!__traits(compiles, sc = w));
    sc = sw;

    static assert(!__traits(compiles, w = c));
    static assert(!__traits(compiles, w = i));
    static assert(!__traits(compiles, w = s));
    static assert(!__traits(compiles, w = sc));
    w = w;
    static assert(!__traits(compiles, w = sw));

    static assert(!__traits(compiles, sw = c));
    static assert(!__traits(compiles, sw = i));
    static assert(!__traits(compiles, sw = s));
    static assert(!__traits(compiles, sw = sc));
    static assert(!__traits(compiles, sw = w));
    sw = sw;

    return 0;
}

/************************************/

inout(int) test81(inout(int) _ = 0)
{
    const(char)* c;
    immutable(char)* i;
    shared(char)* s;
    const(shared(char))* sc;
    inout(char)* w;

    c = c;
    c = i;
    static assert(!__traits(compiles, c = s));
    static assert(!__traits(compiles, c = sc));
    c = w;

    static assert(!__traits(compiles, i = c));
    i = i;
    static assert(!__traits(compiles, i = s));
    static assert(!__traits(compiles, i = sc));
    static assert(!__traits(compiles, i = w));

    static assert(!__traits(compiles, s = c));
    static assert(!__traits(compiles, s = i));
    s = s;
    static assert(!__traits(compiles, s = sc));
    static assert(!__traits(compiles, s = w));

    static assert(!__traits(compiles, sc = c));
    sc = i;
    sc = s;
    sc = sc;
    static assert(!__traits(compiles, sc = w));

    static assert(!__traits(compiles, w = c));
    static assert(!__traits(compiles, w = i));
    static assert(!__traits(compiles, w = s));
    static assert(!__traits(compiles, w = sc));
    w = w;

    return 0;
}

/************************************/


inout(int) test82(inout(int) _ = 0)
{
    const(immutable(char)*) c;
    pragma(msg, typeof(c));
    static assert(typeof(c).stringof == "const(immutable(char)*)");

    inout(immutable(char)*) d;
    pragma(msg, typeof(d));
    static assert(typeof(d).stringof == "inout(immutable(char)*)");

    inout(const(char)*) e;

    pragma(msg, typeof(e));
    static assert(is(typeof(e) == inout(const(char)*)));
    static assert(typeof(e).stringof == "inout(const(char)*)");

    pragma(msg, typeof(*e));
    static assert(is(typeof(*e) == const(char)));
    static assert(typeof(*e).stringof == "const(char)");

    inout const(char)* f;
    static assert(is(typeof(e) == typeof(f)));

    inout(shared(char)) g;
    pragma(msg, typeof(g));
    static assert(typeof(g).stringof == "shared(inout(char))");

    shared(inout(char)) h;
    pragma(msg, typeof(h));
    static assert(typeof(h).stringof == "shared(inout(char))");

    inout(immutable(char)) i;
    pragma(msg, typeof(i));
    static assert(typeof(i).stringof == "immutable(char)");

    immutable(inout(char)) j;
    pragma(msg, typeof(j));
    static assert(typeof(j).stringof == "immutable(char)");

    inout(const(char)) k;
    pragma(msg, typeof(k));
    static assert(typeof(k).stringof == "inout(char)");

    const(inout(char)) l;
    pragma(msg, typeof(l));
    static assert(typeof(l).stringof == "const(char)");

    shared(const(char)) m;
    pragma(msg, typeof(m));
    static assert(typeof(m).stringof == "shared(const(char))");

    const(shared(char)) n;
    pragma(msg, typeof(n));
    static assert(typeof(n).stringof == "shared(const(char))");

    inout(char*****) o;
    pragma(msg, typeof(o));
    static assert(typeof(o).stringof == "inout(char*****)");
    pragma(msg, typeof(cast()o));
    static assert(typeof(cast()o).stringof == "char*****");

    const(char*****) p;
    pragma(msg, typeof(p));
    static assert(typeof(p).stringof == "const(char*****)");
    pragma(msg, typeof(cast()p));
    static assert(typeof(cast()p).stringof == "const(char****)*");

    immutable(char*****) q;
    pragma(msg, typeof(q));
    static assert(typeof(q).stringof == "immutable(char*****)");
    pragma(msg, typeof(cast()q));
    static assert(typeof(cast()q).stringof == "immutable(char****)*");

    shared(char*****) r;
    pragma(msg, typeof(r));
    static assert(typeof(r).stringof == "shared(char*****)");
    pragma(msg, typeof(cast()r));
    static assert(typeof(cast()r).stringof == "shared(char****)*");
    pragma(msg, typeof(cast(const)r));
    static assert(typeof(cast(const)r).stringof == "const(shared(char****)*)");
    pragma(msg, typeof(cast(const shared)r));
    static assert(typeof(cast(const shared)r).stringof == "shared(const(char*****))");
    pragma(msg, typeof(cast(shared)r));
    static assert(typeof(cast(shared)r).stringof == "shared(char*****)");
    pragma(msg, typeof(cast(immutable)r));
    static assert(typeof(cast(immutable)r).stringof == "immutable(char*****)");
    pragma(msg, typeof(cast(inout)r));
    static assert(typeof(cast(inout)r).stringof == "inout(shared(char****)*)");

    inout(shared(char**)***) s;
    pragma(msg, typeof(s));
    static assert(typeof(s).stringof == "inout(shared(char**)***)");
    pragma(msg, typeof(***s));
    static assert(typeof(***s).stringof == "shared(inout(char**))");

    return 0;
}

/************************************/

inout(int) test83(inout(int) _ = 0)
{
    static assert(!__traits(compiles, typeid(int* function(inout int))));
    static assert(!__traits(compiles, typeid(inout(int*) function(int))));
    static assert(!__traits(compiles, typeid(inout(int*) function())));
    inout(int*) function(inout(int)) fp;

    return 0;
}

/************************************/

inout(char[]) foo84(inout char[] s) { return s; }

void test84()
{
    char[] m;
    const(char)[] c;
    string s;
    auto r = foo84(s);
    pragma(msg, typeof(r).stringof);
    static assert(typeof(r).stringof == "immutable(char[])");

    pragma(msg, typeof(foo84(c)).stringof);
    static assert(typeof(foo84(c)).stringof == "const(char[])");

    pragma(msg, typeof(foo84(m)).stringof);
    static assert(typeof(foo84(m)).stringof == "char[]");
}

/************************************/

class foo85 { }

alias shared foo85 Y85;

void test85()
{
   pragma(msg, Y85);
   shared(foo85) x = new Y85;
}

/************************************/

struct foo87
{
    int bar(T)(T t){ return 1; }
    int bar(T)(T t) shared { return 2; }
}

void test87()
{
    foo87 x;
    auto i = x.bar(1);
    assert(i == 1);
    shared foo87 y;
    i = y.bar(1);
    assert(i == 2);
}

/************************************/
// 2751


void test88(immutable(int[3]) a)
{
    const(char)[26] abc1 = "abcdefghijklmnopqrstuvwxyz";
    const(char[26]) abc2 = "abcdefghijklmnopqrstuvwxyz";
    immutable(const(char)[26]) abc3 = "abcdefghijklmnopqrstuvwxyz";
    const(immutable(char)[26]) abc4 = "abcdefghijklmnopqrstuvwxyz";

    auto abc5 = cast()"abcdefghijklmnopqrstuvwxyz";

    pragma(msg, typeof(abc1).stringof);
    pragma(msg, typeof(abc2).stringof);
    pragma(msg, typeof(abc3).stringof);
    pragma(msg, typeof(abc4).stringof);
    pragma(msg, typeof(abc5).stringof);

    static assert(is(typeof(abc1) == typeof(abc2)));
    static assert(is(typeof(abc1) == const(char[26])));
    static assert(is(typeof(abc3) == typeof(abc4)));
    static assert(is(typeof(abc3) == immutable(char[26])));

    auto b = cast()a;
    pragma(msg, typeof(b).stringof);
    static assert(is(typeof(b) == int[3]));
}

/************************************/
// 3748

// version = error8;
// version = error11;

class C3748
{
    private int _x;
    this(int x) { this._x = x; }
    @property inout(int)* xptr() inout { return &_x; }
    @property void x(int newval) { _x = newval; }
}

struct S3748
{
    int x;
    immutable int y = 5;
    const int z = 6;
    C3748 c;

    inout(int)* getX() inout
    {
        static assert(!__traits(compiles, {
            x = 4;
        }));
        return &x;
    }
    inout(int)* getCX(C3748 otherc) inout
    {
        inout(C3748) c2 = c;    // typeof(c) == inout(C3748)
        static assert(!__traits(compiles, {
            inout(C3748) err2 = new C3748(1);
        }));
        static assert(!__traits(compiles, {
            inout(C3748) err3 = otherc;
        }));

        auto v1 = getLowestXptr(c, otherc);
        static assert(is(typeof(v1) == const(int)*));
        auto v2 = getLowestXptr(c, c);
        static assert(is(typeof(v2) == inout(int)*));

        alias typeof(return) R;
        static assert(!__traits(compiles, {
            c.x = 4;
        }));
        static assert(!__traits(compiles, {
            R r = otherc.xptr;
        }));
        static assert(!__traits(compiles, {
            R r = &y;
        }));
        static assert(!__traits(compiles, {
            R r = &z;
        }));

        return c2.xptr;
    }

    version(error8)
        inout(int) err8;    // see fail_compilation/failinout3748a.d
}

inout(int)* getLowestXptr(inout(C3748) c1, inout(C3748) c2)
{
    inout(int)* x1 = c1.xptr;
    inout(int)* x2 = c2.xptr;
    if(*x1 <= *x2)
        return x1;
    return x2;
}

ref inout(int) getXRef(inout(C3748) c1, inout(C3748) c2)
{
    return *getLowestXptr(c1, c2);
}

void test3748()
{
    S3748 s;
    s.c = new C3748(1);
    const(S3748)* sp = &s;
    auto s2 = new S3748;
    s2.x = 3;
    s2.c = new C3748(2);
    auto s3 = cast(immutable(S3748)*) s2;

    auto v1 = s.getX;
    static assert(is(typeof(v1) == int*));
    auto v2 = sp.getX;
    static assert(is(typeof(v2) == const(int)*));
    auto v3 = s3.getX;
    static assert(is(typeof(v3) == immutable(int)*));

    static assert(!__traits(compiles, {
        int *err9 = sp.getX;
    }));
    static assert(!__traits(compiles, {
        int *err10 = s3.getX;
    }));
    version(error11)
        inout(int)* err11;  // see fail_compilation/failinout3748b.d

    auto v4 = getLowestXptr(s.c, s3.c);
    static assert(is(typeof(v4) == const(int)*));
    auto v5 = getLowestXptr(s.c, s.c);
    static assert(is(typeof(v5) == int*));
    auto v6 = getLowestXptr(s3.c, s3.c);
    static assert(is(typeof(v6) == immutable(int)*));

    getXRef(s.c, s.c) = 3;
}

/************************************/
// 4968

void test4968()
{
    inout(int) f1(inout(int) i) { return i; }
    int mi;
    const int ci;
    immutable int ii;
    static assert(is(typeof(f1(mi)) == int));
    static assert(is(typeof(f1(ci)) == const(int)));
    static assert(is(typeof(f1(ii)) == immutable(int)));

    inout(int)* f2(inout(int)* p) { return p; }
    int* mp;
    const(int)* cp;
    immutable(int)* ip;
    static assert(is(typeof(f2(mp)) == int*));
    static assert(is(typeof(f2(cp)) == const(int)*));
    static assert(is(typeof(f2(ip)) == immutable(int)*));

    inout(int)[] f3(inout(int)[] a) { return a; }
    int[] ma;
    const(int)[] ca;
    immutable(int)[] ia;
    static assert(is(typeof(f3(ma)) == int[]));
    static assert(is(typeof(f3(ca)) == const(int)[]));
    static assert(is(typeof(f3(ia)) == immutable(int)[]));

    inout(int)[1] f4(inout(int)[1] sa) { return sa; }
    int[1] msa;
    const int[1] csa;
    immutable int[1] isa;
    static assert(is(typeof(f4(msa)) == int[1]));
    static assert(is(typeof(f4(csa)) == const(int)[1]));
    static assert(is(typeof(f4(isa)) == immutable(int)[1]));

    inout(int)[string] f5(inout(int)[string] aa) { return aa; }
    int[string] maa;
    const int[string] caa;
    immutable int[string] iaa;
    static assert(is(typeof(f5(maa)) == int[string]));
    static assert(is(typeof(f5(caa)) == const(int)[string]));
    static assert(is(typeof(f5(iaa)) == immutable(int)[string]));
}

/************************************/
// 1961

inout(char)[] strstr(inout(char)[] source, const(char)[] pattern)
{
    /*
     * this would be an error, as const(char)[] is not implicitly castable to
     * inout(char)[]
     */
    // return pattern;

    for(int i = 0; i + pattern.length <= source.length; i++)
    {
        inout(char)[] tmp = source[i..pattern.length]; // ok
        if (tmp == pattern)         // ok, tmp implicitly casts to const(char)[]
            return source[i..$];    // implicitly casts back to call-site source
    }
    return source[$..$];            // to be consistent with strstr.
}

void test1961a()
{
    auto a = "hello";
    a = strstr(a, "llo");   // cf (constancy factor) == immutable
    static assert(!__traits(compiles, { char[] b = strstr(a, "llo"); }));
                            // error, cannot cast immutable to mutable
    char[] b = "hello".dup;
    b = strstr(b, "llo");   // cf == mutable (note that "llo" doesn't play a role
                            // because that parameter is not inout)
    const(char)[] c = strstr(b, "llo");
                            // cf = mutable, ok because mutable
                            // implicitly casts to const
    c = strstr(a, "llo");   // cf = immutable, ok immutable casts to const
}

inout(T) min(T)(inout(T) a, inout(T) b)
{
    return a < b ? a : b;
}

void test1961b()
{
    immutable(char)[] i = "hello";
    const(char)[] c = "there";
    char[] m = "Walter".dup;

    static assert(!__traits(compiles, { i = min(i, c); }));
                            // error, since i and c vary in constancy, the result
                            // is const, and you cannot implicitly cast const to immutable.

    c = min(i, c);          // ok, cf == const, because not homogeneous
    c = min(m, c);          // ok, cf == const
    c = min(m, i);          // ok, cf == const
    i = min(i, "blah");     // ok, cf == immutable, homogeneous
    static assert(!__traits(compiles, { m = min(m, c); }));
                            // error, cf == const because not homogeneous.
    static assert(!__traits(compiles, { m = min(m, "blah"); }));
                            // error, cf == const
    m = min(m, "blah".dup); // ok
}

inout(T) min2(int i, int j, T)(inout(T) a, inout(T) b)
{
    //pragma(msg, "(", i, ", ", j, ") = ", T);
    static if (i == 0)
    {
        static if (j == 0) static assert(is(T == immutable(char)[]));
        static if (j == 1) static assert(is(T == immutable(char)[]));
        static if (j == 2) static assert(is(T == const(char)[]));
        static if (j == 3) static assert(is(T == const(char)[]));
        static if (j == 4) static assert(is(T == const(char)[]));
    }
    static if (i == 1)
    {
        static if (j == 0) static assert(is(T == immutable(char)[]));
        static if (j == 1) static assert(is(T == immutable(char)[]));
        static if (j == 2) static assert(is(T == const(char)[]));
        static if (j == 3) static assert(is(T == const(char)[]));
        static if (j == 4) static assert(is(T == const(char)[]));
    }
    static if (i == 2)
    {
        static if (j == 0) static assert(is(T == const(char)[]));
        static if (j == 1) static assert(is(T == const(char)[]));
        static if (j == 2) static assert(is(T == const(char)[]));
        static if (j == 3) static assert(is(T == const(char)[]));
        static if (j == 4) static assert(is(T == const(char)[]));
    }
    static if (i == 3)
    {
        static if (j == 0) static assert(is(T == const(char)[]));
        static if (j == 1) static assert(is(T == const(char)[]));
        static if (j == 2) static assert(is(T == const(char)[]));
        static if (j == 3) static assert(is(T == const(char)[]));
        static if (j == 4) static assert(is(T == const(char)[]));
    }
    static if (i == 4)
    {
        static if (j == 0) static assert(is(T == const(char)[]));
        static if (j == 1) static assert(is(T == const(char)[]));
        static if (j == 2) static assert(is(T == const(char)[]));
        static if (j == 3) static assert(is(T == const(char)[]));
        static if (j == 4) static assert(is(T == char[]));
    }
    return a < b ? a : b;
}

template seq(T...){ alias T seq; }

void test1961c()
{
    immutable(char[]) iia = "hello1";
    immutable(char)[] ima = "hello2";
    const(char[]) cca = "there1";
    const(char)[] cma = "there2";
    char[] mma = "Walter".dup;

    foreach (i, x; seq!(iia, ima, cca, cma, mma))
    foreach (j, y; seq!(iia, ima, cca, cma, mma))
    {
        min2!(i, j)(x, y);
        //pragma(msg, "x: ",typeof(x), ", y: ",typeof(y), " -> ", typeof(min2(x, y)), " : ", __traits(compiles, min2(x, y)));
        /+
        x: immutable(char[])    , y: immutable(char[]) -> immutable(char[])         : true
        x: immutable(char[])    , y: immutable(char)[] -> const(immutable(char)[])  : true
        x: immutable(char[])    , y: const(char[])     -> const(char[])             : true
        x: immutable(char[])    , y: const(char)[]     -> const(char[])             : true
        x: immutable(char[])    , y: char[]            -> const(char[])             : true

        x: immutable(char)[]    , y: immutable(char[]) -> const(immutable(char)[])  : true
        x: immutable(char)[]    , y: immutable(char)[] -> immutable(char)[]         : true
        x: immutable(char)[]    , y: const(char[])     -> const(char[])             : true
        x: immutable(char)[]    , y: const(char)[]     -> const(char)[]             : true
        x: immutable(char)[]    , y: char[]            -> const(char)[]             : true

        x: const(char[])        , y: immutable(char[]) -> const(char[])             : true
        x: const(char[])        , y: immutable(char)[] -> const(char[])             : true
        x: const(char[])        , y: const(char[])     -> const(char[])             : true
        x: const(char[])        , y: const(char)[]     -> const(char[])             : true
        x: const(char[])        , y: char[]            -> const(char[])             : true

        x: const(char)[]        , y: immutable(char[]) -> const(char[])             : true
        x: const(char)[]        , y: immutable(char)[] -> const(char)[]             : true
        x: const(char)[]        , y: const(char[])     -> const(char[])             : true
        x: const(char)[]        , y: const(char)[]     -> const(char)[]             : true
        x: const(char)[]        , y: char[]            -> const(char)[]             : true

        x: char[]               , y: immutable(char[]) -> const(char[])             : true
        x: char[]               , y: immutable(char)[] -> const(char)[]             : true
        x: char[]               , y: const(char[])     -> const(char[])             : true
        x: char[]               , y: const(char)[]     -> const(char)[]             : true
        x: char[]               , y: char[]            -> char[]                    : true
        +/
    }
}

/************************************/

inout(int) function(inout(int)) notinoutfun1() { return null; }
inout(int) delegate(inout(int)) notinoutfun2() { return null; }
void notinoutfun1(inout(int) function(inout(int)) fn) {}
void notinoutfun2(inout(int) delegate(inout(int)) dg) {}

void test88()
{
    inout(int) function(inout(int)) fp;
    inout(int) delegate(inout(int)) dg;

    static assert(!__traits(compiles, {
        inout(int)* p;
    }));
}

/************************************/
// 6782

struct Tuple6782(T...)
{
    T field;
    alias field this;
}
auto tuple6782(T...)(T field)
{
    return Tuple6782!T(field);
}

struct Range6782a
{
    int *ptr;
    @property inout(int)* front() inout { return ptr; }
    @property bool empty() const { return ptr is null; }
    void popFront() { ptr = null; }
}
struct Range6782b
{
    Tuple6782!(int, int*) e;
    @property front() inout { return e; }
    @property empty() const { return e[1] is null; }
    void popFront() { e[1] = null; }
}

void test6782()
{
    int x = 5;
    auto r1 = Range6782a(&x);
    foreach(p; r1) {}

    auto r2 = Range6782b(tuple6782(1, &x));
    foreach(i, p; r2) {}
}

/************************************/
// 6864

int fn6864( const int n) { return 1; }
int fn6864(shared int n) { return 2; }
inout(int) fw6864(inout int s) { return 1; }
inout(int) fw6864(shared inout int s) { return 2; }

void test6864()
{
    int n;
    assert(fn6864(n) == 1);
    assert(fw6864(n) == 1);

    shared int sn;
    assert(fn6864(sn) == 2);
    assert(fw6864(sn) == 2);
}

/************************************/
// 6865

shared(inout(int)) foo6865(shared(inout(int)) n){ return n; }
void test6865()
{
    shared(const(int)) n;
    static assert(is(typeof(foo6865(n)) == shared(const(int))));
}

/************************************/
// 6866

struct S6866
{
    const(char)[] val;
    alias val this;
}
inout(char)[] foo6866(inout(char)[] s) { return s; }

void test6866()
{
    S6866 s;
    static assert(is(typeof(foo6866(s)) == const(char)[]));
    // Assertion failure: 'targ' on line 2029 in file 'mtype.c'
}

/************************************/
// 6867

inout(char)[] test6867(inout(char)[] a)
{
   foreach(dchar d; a) // No error if 'dchar' is removed
   {
       foreach(c; a) // line 5
       {
       }
   }
   return [];
}

/************************************/
// 6870

void test6870()
{
   shared(int) x;
   static assert(is(typeof(x) == shared(int))); // pass
   const(typeof(x)) y;
   const(shared(int)) z;
   static assert(is(typeof(y) == typeof(z))); // fail!
}

/************************************/
// 6338, 6922

alias int T;

static assert(is( immutable(       T )  == immutable(T) ));
static assert(is( immutable( const(T))  == immutable(T) )); // 6922
static assert(is( immutable(shared(T))  == immutable(T) ));
static assert(is( immutable( inout(T))  == immutable(T) ));
static assert(is(        immutable(T)   == immutable(T) ));
static assert(is(  const(immutable(T))  == immutable(T) )); // 6922
static assert(is( shared(immutable(T))  == immutable(T) )); // 6338
static assert(is(  inout(immutable(T))  == immutable(T) ));

static assert(is( immutable(shared(const(T))) == immutable(T) ));
static assert(is( immutable(const(shared(T))) == immutable(T) ));
static assert(is( shared(immutable(const(T))) == immutable(T) ));
static assert(is( shared(const(immutable(T))) == immutable(T) ));
static assert(is( const(shared(immutable(T))) == immutable(T) ));
static assert(is( const(immutable(shared(T))) == immutable(T) ));

static assert(is( immutable(shared(inout(T))) == immutable(T) ));
static assert(is( immutable(inout(shared(T))) == immutable(T) ));
static assert(is( shared(immutable(inout(T))) == immutable(T) ));
static assert(is( shared(inout(immutable(T))) == immutable(T) ));
static assert(is( inout(shared(immutable(T))) == immutable(T) ));
static assert(is( inout(immutable(shared(T))) == immutable(T) ));

/************************************/
// 6912

void test6912()
{
    //                 From                      To
    static assert( is(                 int []  :                 int []  ));
    static assert(!is(           inout(int []) :                 int []  ));
    static assert(!is(                 int []  :           inout(int []) ));
    static assert( is(           inout(int []) :           inout(int []) ));

    static assert( is(                 int []  :           const(int)[]  ));
    static assert( is(           inout(int []) :           const(int)[]  ));
    static assert(!is(                 int []  :     inout(const(int)[]) ));
    static assert( is(           inout(int []) :     inout(const(int)[]) ));

    static assert( is(           const(int)[]  :           const(int)[]  ));
    static assert( is(     inout(const(int)[]) :           const(int)[]  ));
    static assert(!is(           const(int)[]  :     inout(const(int)[]) ));
    static assert( is(     inout(const(int)[]) :     inout(const(int)[]) ));

    static assert( is(       immutable(int)[]  :           const(int)[]  ));
    static assert( is( inout(immutable(int)[]) :           const(int)[]  ));
    static assert( is(       immutable(int)[]  :     inout(const(int)[]) ));
    static assert( is( inout(immutable(int)[]) :     inout(const(int)[]) ));

    static assert( is(       immutable(int)[]  :       immutable(int)[]  ));
    static assert( is( inout(immutable(int)[]) :       immutable(int)[]  ));
    static assert( is(       immutable(int)[]  : inout(immutable(int)[]) ));
    static assert( is( inout(immutable(int)[]) : inout(immutable(int)[]) ));

    static assert( is(           inout(int)[]  :           inout(int)[]  ));
    static assert( is(     inout(inout(int)[]) :           inout(int)[]  ));
    static assert( is(           inout(int)[]  :     inout(inout(int)[]) ));
    static assert( is(     inout(inout(int)[]) :     inout(inout(int)[]) ));

    static assert( is(           inout(int)[]  :           const(int)[]  ));
    static assert( is(     inout(inout(int)[]) :           const(int)[]  ));
    static assert( is(           inout(int)[]  :     inout(const(int)[]) ));
    static assert( is(     inout(inout(int)[]) :     inout(const(int)[]) ));

    //                 From                         To
    static assert( is(                 int [int]  :                 int [int]  ));
    static assert(!is(           inout(int [int]) :                 int [int]  ));
    static assert(!is(                 int [int]  :           inout(int [int]) ));
    static assert( is(           inout(int [int]) :           inout(int [int]) ));

    static assert( is(                 int [int]  :           const(int)[int]  ));
    static assert( is(           inout(int [int]) :           const(int)[int]  ));
    static assert(!is(                 int [int]  :     inout(const(int)[int]) ));
    static assert( is(           inout(int [int]) :     inout(const(int)[int]) ));

    static assert( is(           const(int)[int]  :           const(int)[int]  ));
    static assert( is(     inout(const(int)[int]) :           const(int)[int]  ));
    static assert(!is(           const(int)[int]  :     inout(const(int)[int]) ));
    static assert( is(     inout(const(int)[int]) :     inout(const(int)[int]) ));

    static assert( is(       immutable(int)[int]  :           const(int)[int]  ));
    static assert( is( inout(immutable(int)[int]) :           const(int)[int]  ));
    static assert( is(       immutable(int)[int]  :     inout(const(int)[int]) ));
    static assert( is( inout(immutable(int)[int]) :     inout(const(int)[int]) ));

    static assert( is(       immutable(int)[int]  :       immutable(int)[int]  ));
    static assert( is( inout(immutable(int)[int]) :       immutable(int)[int]  ));
    static assert( is(       immutable(int)[int]  : inout(immutable(int)[int]) ));
    static assert( is( inout(immutable(int)[int]) : inout(immutable(int)[int]) ));

    static assert( is(           inout(int)[int]  :           inout(int)[int]  ));
    static assert( is(     inout(inout(int)[int]) :           inout(int)[int]  ));
    static assert( is(           inout(int)[int]  :     inout(inout(int)[int]) ));
    static assert( is(     inout(inout(int)[int]) :     inout(inout(int)[int]) ));

    static assert( is(           inout(int)[int]  :           const(int)[int]  ));
    static assert( is(     inout(inout(int)[int]) :           const(int)[int]  ));
    static assert( is(           inout(int)[int]  :     inout(const(int)[int]) ));
    static assert( is(     inout(inout(int)[int]) :     inout(const(int)[int]) ));

    // Regression check
    static assert( is( const(int)[] : const(int[]) ) );

    //                 From                     To
    static assert( is(                 int *  :                 int *  ));
    static assert(!is(           inout(int *) :                 int *  ));
    static assert(!is(                 int *  :           inout(int *) ));
    static assert( is(           inout(int *) :           inout(int *) ));

    static assert( is(                 int *  :           const(int)*  ));
    static assert( is(           inout(int *) :           const(int)*  ));
    static assert(!is(                 int *  :     inout(const(int)*) ));
    static assert( is(           inout(int *) :     inout(const(int)*) ));

    static assert( is(           const(int)*  :           const(int)*  ));
    static assert( is(     inout(const(int)*) :           const(int)*  ));
    static assert(!is(           const(int)*  :     inout(const(int)*) ));
    static assert( is(     inout(const(int)*) :     inout(const(int)*) ));

    static assert( is(       immutable(int)*  :           const(int)*  ));
    static assert( is( inout(immutable(int)*) :           const(int)*  ));
    static assert( is(       immutable(int)*  :     inout(const(int)*) ));
    static assert( is( inout(immutable(int)*) :     inout(const(int)*) ));

    static assert( is(       immutable(int)*  :       immutable(int)*  ));
    static assert( is( inout(immutable(int)*) :       immutable(int)*  ));
    static assert( is(       immutable(int)*  : inout(immutable(int)*) ));
    static assert( is( inout(immutable(int)*) : inout(immutable(int)*) ));

    static assert( is(           inout(int)*  :           inout(int)*  ));
    static assert( is(     inout(inout(int)*) :           inout(int)*  ));
    static assert( is(           inout(int)*  :     inout(inout(int)*) ));
    static assert( is(     inout(inout(int)*) :     inout(inout(int)*) ));

    static assert( is(           inout(int)*  :           const(int)*  ));
    static assert( is(     inout(inout(int)*) :           const(int)*  ));
    static assert( is(           inout(int)*  :     inout(const(int)*) ));
    static assert( is(     inout(inout(int)*) :     inout(const(int)*) ));
}

/************************************/
// 6941

static assert((const(shared(int[])[])).stringof == "const(shared(int[])[])");	// fail
static assert((const(shared(int[])[])).stringof != "const(shared(const(int[]))[])"); // fail

static assert((inout(shared(int[])[])).stringof == "inout(shared(int[])[])");	// fail
static assert((inout(shared(int[])[])).stringof != "inout(shared(inout(int[]))[])");	// fail

/************************************/
// 6872

static assert((shared(inout(int)[])).stringof == "shared(inout(int)[])");
static assert((shared(inout(const(int)[]))).stringof == "shared(inout(const(int)[]))");
static assert((shared(inout(const(int)[])[])).stringof == "shared(inout(const(int)[])[])");
static assert((shared(inout(const(immutable(int)[])[])[])).stringof == "shared(inout(const(immutable(int)[])[])[])");

/************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
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
    test53();
    test54();
    test55();
    test56();
    test57();
    test58();
    test59();
    test60();
    test61();
    test62();
    test63();
    test64();
    test65();
    test66();
    test68();
    test69();
    test70();
    test72();
    test73();
    test74();
    test75();
    test76();
    test77();
    test78();
    test79();
    test80();
    test81();
    test82();
    test83();
    test84();
    test85();
    test87();
    test4968();
    test3748();
    test1961a();
    test1961b();
    test1961c();
    test88();
    test6782();
    test6864();
    test6865();
    test6866();
    test6870();
    test6912();

    printf("Success\n");
    return 0;
}
