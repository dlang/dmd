
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

S6 foo6(void)
{
    S6 s;
    s.i = 42;
    s.d = 2.5;
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

struct MyStructType { };
void foo10(const MyStructType s, const MyStructType t) { }

enum MyEnumType { onemember };
void foo10(const MyEnumType s, const MyEnumType t) { }


