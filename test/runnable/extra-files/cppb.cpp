
#include <stdio.h>
#include <assert.h>

/**************************************/

int foo(int i, int j, int k);

int foob(int i, int j, int k)
{
    printf("i = %d\n", i);
    printf("j = %d\n", j);
    printf("k = %d\n", k);
    assert(i == 1);
    assert(j == 2);
    assert(k == 3);

    foo(i, j, k);

    return 7;
}

/**************************************/

class D *dthis;

class D
{
  public:
    virtual int bar(int i, int j, int k)
    {
    printf("this = %p\n", this);
    assert(this == dthis);
    printf("D.bar: i = %d\n", i);
    printf("D.bar: j = %d\n", j);
    printf("D.bar: k = %d\n", k);
    assert(i == 9);
    assert(j == 10);
    assert(k == 11);
    return 8;
    }
};


D* getD()
{
    D *d = new D();
    dthis = d;
    return d;
}

/**************************************/

class E
{
  public:
    virtual int bar(int i, int j, int k);
};


int callE(E *e)
{
    return e->bar(11,12,13);
}

/**************************************/

void foo4(char *p)
{
}

/**************************************/

struct foo5 { int i; int j; void *p; };

class bar5
{
public:
  virtual foo5 getFoo(int i){
    printf("This = %p\n", this);
    foo5 f;
    f.i = 1;
    f.j = 2 + i;
    f.p = (void*)this;
    return f;
  }
};

bar5* newBar()
{
  bar5* b = new bar5();
  printf("bar = %p\n", b);
  return b;
}


/**************************************/

struct A11802;
struct B11802;

class C11802
{
public:
    virtual void fun(A11802 *);
    virtual void fun(B11802 *);
};

class D11802 : public C11802
{
public:
    void fun(A11802 *);
    void fun(B11802 *);
};

void test11802x(D11802 *c)
{
    c->fun((A11802 *)0);
    c->fun((B11802 *)0);
}

/**************************************/

typedef struct
{
    int i;
    double d;
} S6;

union S6_2
{
    int i;
    double d;
};

enum S6_3
{
    A, B
};


S6 foo6(void)
{
    S6 s;
    s.i = 42;
    s.d = 2.5;
    return s;
}

S6_2 foo6_2(void)
{
    S6_2 s;
    s.i = 42;
    return s;
}

S6_3 foo6_3(void)
{
    S6_3 s = A;
    return s;
}

extern "C" { int foosize6()
{
    return sizeof(S6);
}
}

/**************************************/

typedef struct
{
    int i;
    long long d;
} S7;

extern "C" { int foo7()
{
    return sizeof(S7);
}
}

/**************************************/

struct Struct10071
{
    void *p;
    long double r;
};

size_t offset10071()
{
    Struct10071 s;
    return (char *)&s.r - (char *)&s;
}

/**************************************/

void foo8(const char *p)
{
}

/**************************************/
// 4059

struct elem9 { };
void foobar9(elem9*, elem9*) { }

/**************************************/
// 5148

void foo10(const char*, const char*) { }
void foo10(const int, const int) { }
void foo10(const char, const char) { }
void foo10(bool, bool) { }

struct MyStructType { };
void foo10(const MyStructType s, const MyStructType t) { }

enum MyEnumType { onemember };
void foo10(const MyEnumType s, const MyEnumType t) { }

/**************************************/

namespace N11 { namespace M { void bar11() { } } }

namespace A11 { namespace B { namespace C { void bar() { } } } }

/**************************************/

void myvprintfx(const char* format, va_list);

void myvprintf(const char* format, va_list va)
{
    myvprintfx(format, va);
}

/**************************************/

class C13161
{
public:
        virtual void dummyfunc() {}
        long long val_5;
        unsigned val_9;
};

class Test : public C13161
{
public:
        unsigned val_0;
        long long val_1;
};

size_t getoffset13161()
{
    Test s;
    return (char *)&s.val_0 - (char *)&s;
}

class C13161a
{
public:
        virtual void dummyfunc() {}
        long double val_5;
        unsigned val_9;
};

class Testa : public C13161a
{
public:
        bool val_0;
};

size_t getoffset13161a()
{
    Testa s;
    return (char *)&s.val_0 - (char *)&s;
}

/****************************************************/

#if __linux__ || __APPLE__ || __FreeBSD__
#include <memory>
#include <vector>
#include <string>

#if __linux__
template struct std::allocator<int>;
template struct std::vector<int>;

void foo15()
{
    std::allocator<int>* p;
    p->deallocate(0, 0);
}

#endif

// _Z5foo14PSt6vectorIiSaIiEE
void foo14(std::vector<int, std::allocator<int> > *p) { }

void foo14a(std::basic_string<char> *p) { }
void foo14b(std::basic_string<int> *p) { }
void foo14c(std::basic_istream<char> *p) { }
void foo14d(std::basic_ostream<char> *p) { }
void foo14e(std::basic_iostream<char> *p) { }

void foo14f(std::char_traits<char>* x, std::basic_string<char> *p, std::basic_string<char> *q) { }

#endif

/**************************************/

wchar_t f13289_cpp_wchar_t(wchar_t ch)
{
    if (ch <= L'z' && ch >= L'a')
    {
        return ch - (L'a' - L'A');
    }
    else
    {
        return ch;
    }
}

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
unsigned short f13289_d_wchar(unsigned short ch);
wchar_t f13289_d_dchar(wchar_t ch);
#elif _WIN32
wchar_t f13289_d_wchar(wchar_t ch);
unsigned int f13289_d_dchar(unsigned int ch);
#endif

bool f13289_cpp_test()
{
#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    if (!(f13289_d_wchar((unsigned short)'c') == (unsigned short)'C')) return false;
    if (!(f13289_d_wchar((unsigned short)'D') == (unsigned short)'D')) return false;
    if (!(f13289_d_dchar(L'e') == L'E')) return false;
    if (!(f13289_d_dchar(L'F') == L'F')) return false;
    return true;
#elif _WIN32
    if (!(f13289_d_wchar(L'c') == L'C')) return false;
    if (!(f13289_d_wchar(L'D') == L'D')) return false;
    if (!(f13289_d_dchar((unsigned int)'e') == (unsigned int)'E')) return false;
    if (!(f13289_d_dchar((unsigned int)'F') == (unsigned int)'F')) return false;
    return true;
#else
    return false;
#endif
}

/******************************************/

long double testld(long double ld)
{
    assert(ld == 5);
    return ld + 1;
}

long testl(long lng)
{
    assert(lng == 5);
    return lng + sizeof(long);
}

unsigned long testul(unsigned long ul)
{
    assert(ul == 5);
    return ul + sizeof(unsigned long);
}

/******************************************/

struct S13707
{
    void* a;
    void* b;
    S13707(void *a, void* b)
    {
        this->a = a;
        this->b = b;
    }
};

S13707 func13707()
{
    S13707 pt(NULL, NULL);
    return pt;
}

/******************************************/

