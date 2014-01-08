// EXTRA_CPP_SOURCES: cppb.cpp

version (Win64)
{
// Name mangling isn't compatible with VC yet
pragma(mangle, "?foo@@YAHHHH@Z")
int foo(int i, int j, int k) { return 0; }

void main() {}

}
else
{

import std.c.stdio;

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
    S6 foo6();
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

extern (C++) void foo8(const char *);

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
// 5148

extern (C++)
{
    void foo10(const char*, const char*);
    void foo10(const int, const int);
    void foo10(const char, const char);

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

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test11802();
    test9();
    test10();

    printf("Success\n");
}
}
