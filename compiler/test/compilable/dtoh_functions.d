/+
REQUIRED_ARGS: -HC -c -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler

#pragma once

#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>

struct S final
{
    int32_t i;
    int32_t get(int32_t , int32_t );
    static int32_t get();
    static const int32_t staticVar;
    void useVars(int32_t pi = i, int32_t psv = S::staticVar);
    struct Nested final
    {
        void useStaticVar(int32_t i = S::staticVar);
        Nested()
        {
        }
    };

    S() :
        i()
    {
    }
    S(int32_t i) :
        i(i)
        {}
};

extern "C" int32_t bar(int32_t x);

extern "C" int32_t bar2(int32_t x);

extern "C" int32_t bar4(int32_t x = 42);

extern int32_t baz(int32_t x);

extern int32_t baz2(int32_t x);

extern int32_t baz4(int32_t x = 42);

extern size_t baz5(size_t x = 42);

extern size_t& bazRef(size_t& x);

extern size_t bazOut(size_t& x);

enum class E : int64_t
{
    m = 1LL,
};

enum class MS : uint8_t
{
    dm = 0u,
};

namespace MSN
{
    static S const s = S(42);
};

struct W1 final
{
    MS ms;
    /* MSN */ S msn;
    W1()
    {
    }
    W1(MS ms, /* MSN */ S msn = S(42)) :
        ms(ms),
        msn(msn)
        {}
};

struct W2 final
{
    W1 w1;
    W2() :
        w1()
    {
    }
    W2(W1 w1) :
        w1(w1)
        {}
};

extern W2 w2;

extern void enums(uint64_t e = $?:32=1LLU|64=static_cast<uint64_t>(E::m)$, uint8_t e2 = static_cast<uint8_t>(w2.w1.ms), S s = static_cast<S>(w2.w1.msn));

extern S s;

extern void aggregates(int32_t a = s.i, int32_t b = s.get(1, 2), int32_t c = S::get(), int32_t d = S::staticVar);

struct S2 final
{
    S s;
    struct S3 final
    {
        static int32_t i;
        S3()
        {
        }
    };

    S2() :
        s()
    {
    }
    S2(S s) :
        s(s)
        {}
};

extern S2 s2;

extern void chains(int32_t a = s2.s.i, int32_t b = S2::S3::i);

extern S* ptr;

extern int32_t(*f)(int32_t );

extern void special(int32_t a = ptr->i, int32_t b = ptr->get(1, 2), int32_t j = (*f)(1));

extern void variadic(int32_t __param_0_, ...);
---
+/

int foo(int x)
{
    return x * 42;
}

extern (C) int fun();
extern (C++) int fun2();

extern (C) int bar(int x)
{
    return x * 42;
}

extern (C) static int bar2(int x)
{
    return x * 42;
}

extern (C) private int bar3(int x)
{
    return x * 42;
}

extern (C) int bar4(int x = 42)
{
    return x * 42;
}

extern (C++) int baz(int x)
{
    return x * 42;
}

extern (C++) static int baz2(int x)
{
    return x * 42;
}

extern (C++) private int baz3(int x)
{
    return x * 42;
}

extern (C++) int baz4(int x = 42)
{
    return x * 42;
}

extern (C++) size_t baz5(size_t x = 42)
{
    return x * 42;
}

extern (C++) ref size_t bazRef(return ref size_t x)
{
    return x;
}

extern (C++) size_t bazOut(out size_t x)
{
    return x;
}

extern (C++):

enum E : long
{
    m = 1
}

enum MS : ubyte { dm }
enum MSN : S { s = S(42) }
struct W1 { MS ms; MSN msn; }
struct W2 { W1 w1; }
__gshared W2 w2;

void enums(ulong e = E.m, ubyte e2 = w2.w1.ms, S s = w2.w1.msn) {}

struct S
{
    int i;
    int get(int, int);
    static int get();
    __gshared const int staticVar;

    void useVars(int pi = i, int psv = staticVar) {}

    struct Nested
    {
        void useStaticVar(int i = staticVar) {}
    }
}

__gshared S s;

void aggregates(int a = s.i, int b = s.get(1, 2), int c = S.get(), int d = S.staticVar) {}

struct S2
{

    S s;
    static struct S3
    {
        __gshared int i = 3;
    }
}

__gshared S2 s2;

void chains(int a = s2.s.i, int b = S2.S3.i) {}

__gshared S* ptr;
__gshared int function(int) f;

void special(int a = ptr.i, int b = ptr.get(1, 2), int j = f(1)) {}

import core.stdc.stdarg;
void variadic(int, ...) {}
