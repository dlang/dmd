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
    version(Win64)
    {
    }
    else
    {
        assert(x.x == 9);
    }
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
    version(X86_64)
    {
        version(Windows)
            va_start(ap, format);
        else
            va_start(ap, __va_argsave);
    }
    else
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
	    void deallocate(T*, size_type);
	}
    }
}

extern (C++, std)
{
    struct vector(T, A = allocator!T) { }

    struct allocator(T)
    {
	version (linux)
	{
	    alias size_type = size_t;
	    void deallocate(T* p, size_type sz)
	    {   (cast(__gnu_cxx.new_allocator!T*)&this).deallocate(p, sz); }
	}
    }
}

extern (C++)
{
    version (linux)
        void foo14(std.vector!(int)* p);
    version (OSX)
        void foo14(std.vector!(int)* p);
    version (FreeBSD)
        void foo14(std.vector!(int)* p);
}

void test14()
{
    std.vector!int* p;
    version (linux)
        foo14(p);
    version (OSX)
        foo14(p);
    version (FreeBSD)
        foo14(p);
}

version (linux)
{
    void test14a(std.allocator!int * pa)
    {
	pa.deallocate(null, 0);
    }
}

/****************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test10071();
    test7();
    test8();
    test11802();
    test9();
    test10();
    test11();
    testvalist();
    test12825();
    test13161();
    test14();

    printf("Success\n");
}
