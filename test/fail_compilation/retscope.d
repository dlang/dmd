/*
REQUIRED_ARGS: -dip1000
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/retscope.d(23): Error: scope variable p may not be returned
fail_compilation/retscope.d(33): Error: escaping reference to local variable j
fail_compilation/retscope.d(46): Error: scope variable p assigned to non-scope q
fail_compilation/retscope.d(48): Error: address of variable i assigned to q with longer lifetime
fail_compilation/retscope.d(49): Error: variadic variable a assigned to non-scope b
fail_compilation/retscope.d(50): Error: reference to stack allocated value returned by (*fp2)() assigned to non-scope q
---
*/




int* foo1(return scope int* p) { return p; } // ok

int* foo2()(scope int* p) { return p; }  // ok, 'return' is inferred
alias foo2a = foo2!();

int* foo3(scope int* p) { return p; }   // error

int* foo4(bool b)
{
    int i;
    int j;

    int* nested1(scope int* p) { return null; }
    int* nested2(return scope int* p) { return p; }

    return b ? nested1(&i) : nested2(&j);
}

/************************************************/

struct S2 { int a,b,c,d; }

@safe S2 function() fp2;

void test2(scope int* p, int[] a ...) @safe
{
    static int* q;
    static int[] b;
    q = p;
    int i;
    q = &i;
    b = a;
    q = &fp2().d;
}

/**************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(76): Error: function retscope.HTTP.Impl.onReceive is @nogc yet allocates closures with the GC
fail_compilation/retscope.d(78):        retscope.HTTP.Impl.onReceive.__lambda1 closes over variable this at fail_compilation/retscope.d(76)
---
*/


struct Curl
{
    int delegate() dg;
}

struct HTTP
{
    struct Impl
    {
        Curl curl;
        int x;

        @nogc void onReceive()
        {
            auto dg = ( ) { return x; };
            curl.dg = dg;
        }
    }
}

/***********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(97): Error: reference to local variable sa assigned to non-scope parameter a calling retscope.bar8
---
*/
// https://issues.dlang.org/show_bug.cgi?id=8838

int[] foo8() @safe
{
    int[5] sa;
    return bar8(sa);
}

int[] bar8(int[] a) @safe
{
    return a;
}


/*************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(124): Error: escaping reference to local variable tmp
---
*/

char[] foo9(return char[] a) @safe pure nothrow @nogc
{
    return a;
}

char[] bar9() @safe
{
    char[20] tmp;
    foo9(tmp);          // ok
    return foo9(tmp);   // error
}

/*************************************************/

/*
//
//
//fail_compilation/retscope.d(143): To enforce @safe compiler allocates a closure unless the opApply() uses 'scope'
//
*/

struct S10
{
    static int opApply(int delegate(S10*) dg);
}

S10* test10()
{
    foreach (S10* m; S10)
        return m;
    return null;
}

/************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(159): Error: scope variable this may not be returned
---
*/

class C11
{
    @safe C11 foo() scope { return this; }
}


/****************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(178): Error: address of variable i assigned to p with longer lifetime
---
*/



void foo11() @safe
{
    int[] p;
    int[3] i;
    p = i[];
}

/************************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(198): Error: scope variable e may not be returned
---
*/

struct Escaper
{
    void* DG;
}

void* escapeDg1(scope void* d) @safe
{
    Escaper e;
    e.DG = d;
    return e.DG;
}

/*************************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(213): Error: scope variable p assigned to non-scope e
---
*/
struct Escaper3 { void* e; }

void* escape3 (scope void* p) @safe {
    Escaper3 e;
    scope dg = () { return e.e; };
    e.e = p;
    return dg();
}

/**************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(230): Error: scope variable ptr may not be returned
---
*/

alias dg_t = void* delegate () return scope @safe;

void* funretscope(scope dg_t ptr) @safe
{
    return ptr();
}

/*****************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(249): Error: cannot implicitly convert expression (__lambda1) of type void* delegate() pure nothrow @nogc return @safe to void* delegate() @safe
fail_compilation/retscope.d(249): Error: cannot implicitly convert expression (__lambda1) of type void* delegate() pure nothrow @nogc return @safe to void* delegate() @safe
fail_compilation/retscope.d(250): Error: cannot implicitly convert expression (__lambda2) of type void* delegate() pure nothrow @nogc return @safe to void* delegate() @safe
fail_compilation/retscope.d(250): Error: cannot implicitly convert expression (__lambda2) of type void* delegate() pure nothrow @nogc return @safe to void* delegate() @safe
---
*/

void escape4() @safe
{
    alias FunDG = void* delegate () @safe;
    int x = 42;
    scope FunDG f = () return { return &x; };
    scope FunDG g = ()        { return &x; };
}

/**************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(267): Error: cannot take address of scope local p in @safe function escape5
---
*/

void escape5() @safe
{
    int* q;
    scope int* p;
    scope int** pp = &q; // ok
    pp = &p; // error
}

/***********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(287): Error: escaping reference to local variable b
---
*/

@safe int* foo6()(int* arg)
{
    return arg;
}

int* escape6() @safe
{
    int b;
    return foo6(&b);
}

/***************************************************/

struct S7
{
    int[10] a;
    int[3] abc(int i) @safe
    {
        return a[0 .. 3]; // should not error
    }
}

/***************************************************/

int[3] escape8(scope int[] p) @safe { return p[0 .. 3]; } // should not error
char*[3] escape9(scope char*[] p) @safe { return p[0 .. 3]; }

/***************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(320): Error: reference to local variable i assigned to non-scope f
---
*/

int* escape10() @safe
{
    int i;
    int* f;
    scope int** x = &f;
    f = &i;

    return bar10(x);
}

int* bar10( scope int** ptr ) @safe
{
    return *ptr;
}

/******************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(343): Error: cannot take address of scope local aa in @safe function escape11
---
*/

int* escape11() @safe
{
    int i;
    int*[3] aa = [ &i, null, null ];
    return bar11(&aa[0]);
}

int* bar11(scope int** x) @safe
{
    return foo11(*x);
}

int* foo11(int* x) @safe { return x; }

/******************************************/

void escape15() @safe
{
    int arg;
    const(void)*[1] argsAddresses;
    argsAddresses[0] = // MUST be an array assignment
        (ref arg)@trusted{ return cast(const void*) &arg; }(arg);
}

/******************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(1003): Error: escaping reference to local variable f
---
*/

#line 1000
int* escape12() @safe
{
    Foo12 f;
    return f.foo;
}

struct Foo12
{
    int* foo() return @safe;
}

/******************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(1103): Error: scope variable f assigned to non-scope parameter this calling retscope.Foo13.foo
---
*/

#line 1100
int* escape13() @safe
{
    scope Foo13 f;
    return f.foo;
}

class Foo13
{
    int* foo() return @safe;
}

/******************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(1205): Error: scope variable f14 assigned to non-scope parameter this calling retscope.Foo14.foo
---
*/

#line 1200
int* escape14() @safe
{
    int i;
    Foo14 f14;
    f14.v = &i;
    return f14.foo;
}

struct Foo14
{
    int* v;
    int* foo () @safe { return this.v; }
}

/******************************************/
/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(1311): Error: scope variable u2 assigned to ek with longer lifetime
---
*/

#line 1300
@safe struct U13 {
  int* k;
  int* get() return scope { return k; }
  static int* sget(return scope ref U13 u) { return u.k; }
}

@safe void foo13() {
  int* ek;

  int i;
  auto u2 = U13(&i);
  ek = U13.sget(u2); // Error: scope variable u2 assigned to ek with longer lifetime

  auto u1 = U13(new int);
  ek = u1.get();   // ok
  ek = U13.sget(u1); // ok
}

