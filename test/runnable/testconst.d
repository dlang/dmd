
import std.c.stdio;

class C { }

int ctfe() { return 3; }

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

void test7()
{
    typedef void *HANDLE;
    const HANDLE INVALID_HANDLE_VALUE = cast(HANDLE)-1;
}

/************************************/

class C8 { }

void foo8(const char[] s, const C8 c, const int x)
{
}

void test8()
{
    auto p = &foo8;
    printf("%s\n", p.mangleof.ptr);
    assert(p.mangleof == "PFxAaxC9testconst2C8xiZv");
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
    char[] foo() { return null; }
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
    {	//x = 4;
	//this.x = 5;
    }
}

class C30
{
    int x;

    void foo() { x = 3; }
    void bar() const
    {	//x = 4;
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
    const int b = 3;	// shouldn't be allocated
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
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo43!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == const(int)));
    assert(is(f == const(int)));
  }

  {
    immutable int x;
    alias Foo43!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
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
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo44!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == const(int)));
    assert(is(f == const(int)));
  }

  {
    immutable int x;
    alias Foo44!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
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
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }

  {
    const int x;
    alias Foo45!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == const(int)));
    assert(is(f == int));
  }

  {
    immutable int x;
    alias Foo45!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
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
    printf("%s\n", typeid(f).toString().ptr);
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
    printf("%s\n", typeid(typeof(t)).toString().ptr);
    assert(is(T == immutable(char)));
}

void bar49(T)(const T t)
{
    printf("%s\n", typeid(T).toString().ptr);
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
    printf("%s\n", typeid(typeof(t)).toString().ptr);
    assert(is(T == C));
}

void baz50(T)(T t)
{
    printf("%s\n", typeid(typeof(t)).toString().ptr);
    assert(is(T == const(C)));
}

void bar50(T)(const T t)
{
    printf("%s\n", typeid(T).toString().ptr);
    printf("%s\n", typeid(typeof(t)).toString().ptr);
    assert(is(T == C));
    assert(is(typeof(t) == const(C)));
}

void abc50(T)(const T t)
{
    printf("%s\n", typeid(T).toString().ptr);
    printf("%s\n", typeid(typeof(t)).toString().ptr);
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

    printf("%s\n", typeid(typeof(aa.values)).toString().ptr);
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
	printf("%s\n", typeid(T).toString().ptr);
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
	//c = null;	// should fail
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

void test67()
{
    typedef char mychar;
    alias immutable(mychar)[] mystring;

    mystring s = cast(mystring)"hello";
    mychar c = s[0];
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

void test71()
{
    string s = "hello world";
    char c = s[0];

    typedef char mychar;
    alias immutable(mychar)[] mystring;

    mystring t = cast(mystring)("hello world");
    mychar d = t[0];
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

void test80()
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
//    static assert(!__traits(compiles, c = sw));

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
}

/************************************/

void test81()
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
}

/************************************/


void test82()
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
    static assert(typeof(i).stringof == "inout(char)");

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
    static assert(typeof(cast(const)r).stringof == "const(shared(const(char****))*)");
    pragma(msg, typeof(cast(const shared)r));
    static assert(typeof(cast(const shared)r).stringof == "shared(const(char*****))");
    pragma(msg, typeof(cast(shared)r));
    static assert(typeof(cast(shared)r).stringof == "shared(char*****)");
    pragma(msg, typeof(cast(immutable)r));
    static assert(typeof(cast(immutable)r).stringof == "immutable(char*****)");
    pragma(msg, typeof(cast(inout)r));
    static assert(typeof(cast(inout)r).stringof == "inout(shared(inout(char****))*)");

    inout(shared(char**)***) s;
    pragma(msg, typeof(s));
    static assert(typeof(s).stringof == "inout(shared(inout(char**))***)");
    pragma(msg, typeof(***s));
    static assert(typeof(***s).stringof == "shared(inout(char**))");
}

/************************************/

void test83()
{
    static assert(!__traits(compiles, typeid(int* function(inout int))));
    static assert(!__traits(compiles, typeid(inout(int*) function(int))));
    static assert(!__traits(compiles, typeid(inout(int*) function())));
    inout(int*) function(inout(int)) fp;
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

class foo86 { }

typedef shared foo86 Y86;

void test86()
{
   pragma(msg, Y86);
   shared(Y86) x = new Y86;
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
    test67();
    test68();
    test69();
    test70();
    test71();
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
    test86();
    test87();

    printf("Success\n");
    return 0;
}
