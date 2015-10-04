// PERMUTE_ARGS: -g
// EXTRA_CPP_SOURCES: cppb.cpp

import core.stdc.stdio;
import core.stdc.stdarg;
import core.stdc.config;

extern (C++)
        int foob(int i, int j, int k);

class C
{
    extern (C++) int bar(int i, int j, int k)
    {
        printf("this = %p\n", this);
        printf("i = %d\n", i);
        printf("j = %d\n", j);
        printf("k = %d\n", k);
        return 1;
    }
}


extern (C++)
        int foo(int i, int j, int k)
{
    printf("i = %d\n", i);
    printf("j = %d\n", j);
    printf("k = %d\n", k);
    assert(i == 1);
    assert(j == 2);
    assert(k == 3);
    return 1;
}

void test1()
{
    foo(1, 2, 3);

    auto i = foob(1, 2, 3);
    assert(i == 7);

    C c = new C();
    c.bar(4, 5, 6);
}

/****************************************/

extern (C++) interface D
{
    int bar(int i, int j, int k);
}

extern (C++) D getD();

void test2()
{
    D d = getD();
    int i = d.bar(9,10,11);
    assert(i == 8);
}

/****************************************/

extern (C++) int callE(E);

extern (C++) interface E
{
    int bar(int i, int j, int k);
}

class F : E
{
    extern (C++) int bar(int i, int j, int k)
    {
        printf("F.bar: i = %d\n", i);
        printf("F.bar: j = %d\n", j);
        printf("F.bar: k = %d\n", k);
        assert(i == 11);
        assert(j == 12);
        assert(k == 13);
        return 8;
    }
}

void test3()
{
    F f = new F();
    int i = callE(f);
    assert(i == 8);
}

/****************************************/

extern (C++) void foo4(char* p);

void test4()
{
    foo4(null);
}

/****************************************/

extern(C++)
{
  struct foo5 { int i; int j; void* p; }

  interface bar5{
    foo5 getFoo(int i);
  }

  bar5 newBar();
}

void test5()
{
  bar5 b = newBar();
  foo5 f = b.getFoo(4);
  printf("f.p = %p, b = %p\n", f.p, cast(void*)b);
  assert(f.p == cast(void*)b);
}


/****************************************/

extern(C++)
{
    struct S6
    {
        int i;
        double d;
    }

    union S6_2
    {
        int i;
        double d;
    }

    enum S6_3
    {
        A, B
    }

    S6 foo6();
    S6_2 foo6_2();
    S6_3 foo6_3();
}

extern (C) int foosize6();

void test6()
{
    S6 f = foo6();
    printf("%d %d\n", foosize6(), S6.sizeof);
    assert(foosize6() == S6.sizeof);
version (X86)
{
    assert(f.i == 42);
    printf("f.d = %g\n", f.d);
    assert(f.d == 2.5);
    assert(foo6_2().i == 42);
    assert(foo6_3() == S6_3.A);
}
}

/****************************************/

extern (C) int foo7();

struct S
{
    int i;
    long l;
}

void test7()
{
    printf("%d %d\n", foo7(), S.sizeof);
    assert(foo7() == S.sizeof);
}

/****************************************/

extern (C++) void foo8(const(char)*);

void test8()
{
    char c;
    foo8(&c);
}

/****************************************/
// 4059

struct elem9 { }

extern(C++) void foobar9(elem9*, elem9*);

void test9()
{
    elem9 *a;
    foobar9(a, a);
}

/****************************************/


struct A11802;
struct B11802;

extern(C++) class C11802
{
    int x;
    void fun(A11802*) { x += 2; }
    void fun(B11802*) { x *= 2; }
}

extern(C++) class D11802 : C11802
{
    override void fun(A11802*) { x += 3; }
    override void fun(B11802*) { x *= 3; }
}

extern(C++) void test11802x(D11802);

void test11802()
{
    auto x = new D11802();
    x.x = 0;
    test11802x(x);
    assert(x.x == 9);
}


/****************************************/

struct S13956
{
}

extern(C++) void func13956(S13956 arg0, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6);

extern(C++) void check13956(S13956 arg0, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6)
{
    assert(arg0 == S13956());
    assert(arg1 == 1);
    assert(arg2 == 2);
    assert(arg3 == 3);
    assert(arg4 == 4);
    assert(arg5 == 5);
    assert(arg6 == 6);
}

void test13956()
{
    func13956(S13956(), 1, 2, 3, 4, 5, 6);
}

/****************************************/
// 5148

extern (C++)
{
    void foo10(const(char)*, const(char)*);
    void foo10(const int, const int);
    void foo10(const char, const char);
    void foo10(bool, bool);

    struct MyStructType { }
    void foo10(const MyStructType s, const MyStructType t);

    enum MyEnumType { onemember }
    void foo10(const MyEnumType s, const MyEnumType t);
}

void test10()
{
    char* p;
    foo10(p, p);
    foo10(1,2);
    foo10('c','d');
    MyStructType s;
    foo10(s,s);
    MyEnumType e;
    foo10(e,e);
}

/****************************************/

extern (C++, N11.M) { void bar11(); }

extern (C++, A11.B) { extern (C++, C) { void bar(); }}

void test11()
{
    bar11();
    A11.B.C.bar();
}
/****************************************/

struct Struct10071
{
    void *p;
    c_long_double r;
}

extern(C++) size_t offset10071();
void test10071()
{
    assert(offset10071() == Struct10071.r.offsetof);
}

/****************************************/

char[100] valistbuffer;

extern(C++) void myvprintfx(const(char)* format, va_list va)
{
    vsprintf(valistbuffer.ptr, format, va);
}
extern(C++) void myvprintf(const(char)*, va_list);
extern(C++) void myprintf(const(char)* format, ...)
{
    va_list ap;
    va_start(ap, format);
    myvprintf(format, ap);
    va_end(ap);
}

void testvalist()
{
    myprintf("hello %d", 999);
    assert(valistbuffer[0..9] == "hello 999");
}

/****************************************/
// 12825

extern(C++) class C12825
{
    uint a = 0x12345678;
}

void test12825()
{
    auto c = new C12825();
}

/****************************************/

struct S13955a
{
    float a;
    double b;
}

struct S13955b
{
    double a;
    float b;
}

struct S13955c
{
    float a;
    float b;
}

struct S13955d
{
    double a;
    double b;
}

extern(C++) void check13955(S13955a a, S13955b b, S13955c c, S13955d d)
{
    assert(a.a == 2);
    assert(a.b == 4);
    assert(b.a == 8);
    assert(b.b == 16);
    assert(c.a == 32);
    assert(c.b == 64);
    assert(d.a == 128);
    assert(d.b == 256);
}

extern(C++) void func13955(S13955a a, S13955b b, S13955c c, S13955d d);

void test13955()
{
    func13955(S13955a(2, 4), S13955b(8, 16), S13955c(32, 64), S13955d(128, 256));
}

/****************************************/

extern(C++) class C13161
{
    void dummyfunc() {}
    long val_5;
    uint val_9;
}

extern(C++) class Test : C13161
{
    uint val_0;
    long val_1;
}

extern(C++) size_t getoffset13161();

extern(C++) class C13161a
{
    void dummyfunc() {}
    c_long_double val_5;
    uint val_9;
}

extern(C++) class Testa : C13161a
{
    bool val_0;
}

extern(C++) size_t getoffset13161a();

void test13161()
{
    assert(getoffset13161() == Test.val_0.offsetof);
    assert(getoffset13161a() == Testa.val_0.offsetof);
}

/****************************************/

version (linux)
{
    extern(C++, __gnu_cxx)
    {
	struct new_allocator(T)
	{
	    alias size_type = size_t;
	    static if (is(T : char))
		void deallocate(T*, size_type) { }
	    else
		void deallocate(T*, size_type);
	}
    }
}

extern (C++, std)
{
    struct allocator(T)
    {
	version (linux)
	{
	    alias size_type = size_t;
	    void deallocate(T* p, size_type sz)
	    {   (cast(__gnu_cxx.new_allocator!T*)&this).deallocate(p, sz); }
	}
    }

    version (linux)
    {
	class vector(T, A = allocator!T)
	{
	    final void push_back(ref const T);
	}

	struct char_traits(T)
	{
	}

	struct basic_string(T, C = char_traits!T, A = allocator!T)
	{
	}

	struct basic_istream(T, C = char_traits!T)
	{
	}

	struct basic_ostream(T, C = char_traits!T)
	{
	}

	struct basic_iostream(T, C = char_traits!T)
	{
	}
    }
}

extern (C++)
{
    version (linux)
    {
        void foo14(std.vector!(int) p);
        void foo14a(std.basic_string!(char) *p);
        void foo14b(std.basic_string!(int) *p);
        void foo14c(std.basic_istream!(char) *p);
        void foo14d(std.basic_ostream!(char) *p);
        void foo14e(std.basic_iostream!(char) *p);

	void foo14f(std.char_traits!char* x, std.basic_string!char* p, std.basic_string!char* q);
    }
}

void test14()
{
    version (linux)
    {
        std.vector!int p;
        foo14(p);

	foo14a(null);
	foo14b(null);
	foo14c(null);
	foo14d(null);
	foo14e(null);
	foo14f(null, null, null);
    }
}

version (linux)
{
    void test14a(std.allocator!int * pa)
    {
    pa.deallocate(null, 0);
    }

    void gun(std.vector!int pa)
    {
    int x = 42;
    pa.push_back(x);
    }
}

void test13289()
{
    assert(f13289_cpp_wchar_t('a') == 'A');
    assert(f13289_cpp_wchar_t('B') == 'B');
    assert(f13289_d_wchar('c') == 'C');
    assert(f13289_d_wchar('D') == 'D');
    assert(f13289_d_dchar('e') == 'E');
    assert(f13289_d_dchar('F') == 'F');
    assert(f13289_cpp_test());
}

extern(C++)
{
    bool f13289_cpp_test();

    version(Posix)
    {
        dchar f13289_cpp_wchar_t(dchar);
    }
    else version(Windows)
    {
        wchar f13289_cpp_wchar_t(wchar);
    }

    wchar f13289_d_wchar(wchar ch)
    {
        if (ch <= 'z' && ch >= 'a')
        {
            return cast(wchar)(ch - ('a' - 'A'));
        }
        else
        {
            return ch;
        }
    }
    dchar f13289_d_dchar(dchar ch)
    {
        if (ch <= 'z' && ch >= 'a')
        {
            return ch - ('a' - 'A');
        }
        else
        {
            return ch;
        }
    }
}

/****************************************/

version (CRuntime_Microsoft)
{
    struct __c_long_double
    {
	this(double d) { ld = d; }
	double ld;
	alias ld this;
    }

    alias __c_long_double myld;
}
else
    alias c_long_double myld;

extern (C++) myld testld(myld);


void test15()
{
    myld ld = 5.0;
    ld = testld(ld);
    assert(ld == 6.0);
}

/****************************************/

version( Windows )
{
    alias int   x_long;
    alias uint  x_ulong;
}
else
{
  static if( (void*).sizeof > int.sizeof )
  {
    alias long  x_long;
    alias ulong x_ulong;
  }
  else
  {
    alias int   x_long;
    alias uint  x_ulong;
  }
}

struct __c_long
{
    this(x_long d) { ld = d; }
    x_long ld;
    alias ld this;
}

struct __c_ulong
{
    this(x_ulong d) { ld = d; }
    x_ulong ld;
    alias ld this;
}

alias __c_long mylong;
alias __c_ulong myulong;

extern (C++) mylong testl(mylong);
extern (C++) myulong testul(myulong);


void test16()
{
  {
    mylong ld = 5;
    ld = testl(ld);
    assert(ld == 5 + mylong.sizeof);
  }
  {
    myulong ld = 5;
    ld = testul(ld);
    assert(ld == 5 + myulong.sizeof);
  }
}

/****************************************/

struct S13707
{
    void* a;
    void* b;
    this(void* a, void* b)
    {
        this.a = a;
        this.b = b;
    }
}

extern(C++) S13707 func13707();

void test13707()
{
    auto p = func13707();
    assert(p.a == null);
    assert(p.b == null);
}

/****************************************/

struct S13932(int x)
{
        int member;
}

extern(C++) void func13932(S13932!(-1) s);

/****************************************/

extern(C++, N13337.M13337)
{
  struct S13337{}
  void foo13337(S13337 s);
}

/****************************************/
// 14195

struct Delegate1(T) {}
struct Delegate2(T1, T2) {}

template Signature(T)
{
    alias Signature = typeof(*(T.init));
}

extern(C++)
{
    alias del1_t = Delegate1!(Signature!(void function()));
    alias del2_t = Delegate2!(Signature!(int function(float, double)), Signature!(int function(float, double)));
    void test14195a(del1_t);
    void test14195b(del2_t);
}

void test14195()
{
    test14195a(del1_t());
    test14195b(del2_t());
}


/****************************************/
// 14200

template Tuple14200(T...)
{
  alias Tuple14200 = T;
}

extern(C++) void test14200a(Tuple14200!(int));
extern(C++) void test14200b(float, Tuple14200!(int, double));

void test14200()
{
  test14200a(1);
  test14200b(1.0f, 1, 1.0);
}

/****************************************/
// check order of overloads in vtable

extern (C++) class Statement {}
extern (C++) class ErrorStatement {}
extern (C++) class PeelStatement {}
extern (C++) class ExpStatement {}
extern (C++) class DtorExpStatement {}

extern (C++) class Visitor
{
public:
    int visit(Statement) { return 1; }
    int visit(ErrorStatement) { return 2; }
    int visit(PeelStatement) { return 3; }
}

extern (C++) class Visitor2 : Visitor
{
    int visit2(ExpStatement) { return 4; }
    int visit2(DtorExpStatement) { return 5; }
}

extern(C++) bool testVtableCpp(Visitor2 sv);
extern(C++) Visitor2 getVisitor2();

bool testVtableD(Visitor2 sv)
{
    Statement s1;
    ErrorStatement s2;
    PeelStatement s3;
    ExpStatement s4;
    DtorExpStatement s5;

    if (sv.visit(s1) != 1) return false;
    if (sv.visit(s2) != 2) return false;
    if (sv.visit(s3) != 3) return false;
    if (sv.visit2(s4) != 4) return false;
    if (sv.visit2(s5) != 5) return false;
    return true;
}

void testVtable()
{
    Visitor2 dinst = new Visitor2;
    if (!testVtableCpp(dinst))
        assert(0);

    Visitor2 cppinst = getVisitor2();
    if (!testVtableD(cppinst))
        assert(0);
}

/****************************************/
/* problems detected by fuzzer */
extern(C++) void fuzz1_cppvararg(long arg10, long arg11, bool arg12);
extern(C++) void fuzz1_dvararg(long arg10, long arg11, bool arg12)
{
    fuzz1_checkValues(arg10, arg11, arg12);
}

extern(C++) void fuzz1_checkValues(long arg10, long arg11, bool arg12)
{
    assert(arg10 == 103);
    assert(arg11 == 104);
    assert(arg12 == false);
}

void fuzz1()
{
    long arg10 = 103;
    long arg11 = 104;
    bool arg12 = false;
    fuzz1_dvararg(arg10, arg11, arg12);
    fuzz1_cppvararg(arg10, arg11, arg12);
}

////////
extern(C++) void fuzz2_cppvararg(ulong arg10, ulong arg11, bool arg12);
extern(C++) void fuzz2_dvararg(ulong arg10, ulong arg11, bool arg12)
{
    fuzz2_checkValues(arg10, arg11, arg12);
}

extern(C++) void fuzz2_checkValues(ulong arg10, ulong arg11, bool arg12)
{
    assert(arg10 == 103);
    assert(arg11 == 104);
    assert(arg12 == false);
}

void fuzz2()
{
    ulong arg10 = 103;
    ulong arg11 = 104;
    bool arg12 = false;
    fuzz2_dvararg(arg10, arg11, arg12);
    fuzz2_cppvararg(arg10, arg11, arg12);
}

////////
extern(C++) void fuzz3_cppvararg(wchar arg10, wchar arg11, bool arg12);
extern(C++) void fuzz3_dvararg(wchar arg10, wchar arg11, bool arg12)
{
    fuzz2_checkValues(arg10, arg11, arg12);
}

extern(C++) void fuzz3_checkValues(wchar arg10, wchar arg11, bool arg12)
{
    assert(arg10 == 103);
    assert(arg11 == 104);
    assert(arg12 == false);
}

void fuzz3()
{
    wchar arg10 = 103;
    wchar arg11 = 104;
    bool arg12 = false;
    fuzz3_dvararg(arg10, arg11, arg12);
    fuzz3_cppvararg(arg10, arg11, arg12);
}

void fuzz()
{
    fuzz1();
    fuzz2();
    fuzz3();
}

/****************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test13956();
    test5();
    test6();
    test10071();
    test7();
    test8();
    test11802();
    test9();
    test10();
    test13955();
    test11();
    testvalist();
    test12825();
    test13161();
    test14();
    test13289();
    test15();
    test16();
    func13707();
    func13932(S13932!(-1)(0));
    foo13337(S13337());
    test14195();
    test14200();
    testVtable();
    fuzz();

    printf("Success\n");
}
