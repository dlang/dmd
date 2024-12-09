/*
TEST_OUTPUT:
---
fail_compilation/testInference.d(125): Error: cannot implicitly convert expression `this.a` of type `inout(A8998)` to `immutable(A8998)`
        return a;   // should be error
               ^
fail_compilation/testInference.d(131): Error: cannot implicitly convert expression `s` of type `const(char[])` to `string`
    return s;   //
           ^
fail_compilation/testInference.d(136): Error: cannot implicitly convert expression `a` of type `int[]` to `immutable(int[])`
    return a;   //
           ^
fail_compilation/testInference.d(141): Error: cannot implicitly convert expression `a` of type `int[]` to `immutable(int[])`
    return a;
           ^
fail_compilation/testInference.d(146): Error: cannot implicitly convert expression `a` of type `int[]` to `immutable(int[])`
    return a;   //
           ^
fail_compilation/testInference.d(168): Error: cannot implicitly convert expression `c` of type `testInference.C1` to `immutable(C1)`
immutable(C1) recursive1(C3 pc) pure { auto c = new C1(); return c; }   // should be error, because pc.c1 == C1
                                                                 ^
fail_compilation/testInference.d(169): Error: cannot implicitly convert expression `c` of type `testInference.C1` to `immutable(C1)`
immutable(C1) recursive2(C2 pc) pure { auto c = new C1(); return c; }   // should be error, because pc.c3.c1 == C1
                                                                 ^
fail_compilation/testInference.d(170): Error: cannot implicitly convert expression `c` of type `testInference.C3` to `immutable(C3)`
immutable(C3) recursive3(C1 pc) pure { auto c = new C3(); return c; }   // should be error, c.c1 may be pc
                                                                 ^
fail_compilation/testInference.d(171): Error: cannot implicitly convert expression `c` of type `testInference.C3` to `immutable(C3)`
immutable(C3) recursive4(C2 pc) pure { auto c = new C3(); return c; }   // should be error, c.c1.c2 may be pc
                                                                 ^
fail_compilation/testInference.d(174): Error: undefined identifier `X1`, did you mean function `x1`?
immutable(C1) recursiveE(immutable C2 pc) pure { auto c = new X1(); return c; }
                                                          ^
fail_compilation/testInference.d(180): Error: cannot implicitly convert expression `s` of type `S1` to `immutable(S1)`
immutable(S1)     foo1a(          int*[] prm) pure {                S1 s; return s; }   // NG
                                                                                 ^
fail_compilation/testInference.d(183): Error: cannot implicitly convert expression `a` of type `int*[]` to `immutable(int*[])`
immutable(int*[]) bar1a(              S1 prm) pure {           int *[] a; return a; }   // NG
                                                                                 ^
fail_compilation/testInference.d(184): Error: cannot implicitly convert expression `a` of type `const(int)*[]` to `immutable(int*[])`
immutable(int*[]) bar1b(              S1 prm) pure {     const(int)*[] a; return a; }   // NG
                                                                                 ^
fail_compilation/testInference.d(188): Error: cannot implicitly convert expression `s` of type `S2` to `immutable(S2)`
immutable(S2)     foo2a(          int*[] prm) pure {                S2 s; return s; }   // OK
                                                                                 ^
fail_compilation/testInference.d(189): Error: cannot implicitly convert expression `s` of type `S2` to `immutable(S2)`
immutable(S2)     foo2b(    const int*[] prm) pure {                S2 s; return s; }   // NG
                                                                                 ^
fail_compilation/testInference.d(190): Error: cannot implicitly convert expression `s` of type `S2` to `immutable(S2)`
immutable(S2)     foo2c(immutable int*[] prm) pure {                S2 s; return s; }   // NG
                                                                                 ^
fail_compilation/testInference.d(192): Error: cannot implicitly convert expression `a` of type `const(int)*[]` to `immutable(int*[])`
immutable(int*[]) bar2b(              S2 prm) pure {     const(int)*[] a; return a; }   // NG
                                                                                 ^
fail_compilation/testInference.d(202): Error: cannot implicitly convert expression `f10063(cast(inout(void*))p)` of type `inout(void)*` to `immutable(void)*`
    return f10063(p);
                 ^
fail_compilation/testInference.d(217): Error: `pure` function `testInference.bar14049` cannot call impure function `testInference.foo14049!int.foo14049`
    foo14049(1);
            ^
fail_compilation/testInference.d(212):        which calls `testInference.foo14049!int.foo14049.__lambda_L210_C14`
    }();
     ^
fail_compilation/testInference.d(211):        which calls `testInference.impure14049`
        return impure14049();
                          ^
fail_compilation/testInference.d(206):        which wasn't inferred `pure` because of:
auto impure14049() { static int i = 1; return i; }
                                              ^
fail_compilation/testInference.d(206):        `pure` function `testInference.impure14049` cannot access mutable static data `i`
fail_compilation/testInference.d(223): Error: `pure` function `testInference.f14160` cannot access mutable static data `g14160`
    return &g14160; // should be rejected
            ^
fail_compilation/testInference.d(232): Error: `pure` function `testInference.test12422` cannot call impure function `testInference.test12422.bar12422!().bar12422`
    bar12422();
            ^
fail_compilation/testInference.d(231):        which calls `testInference.foo12422`
    void bar12422()() { foo12422(); }
                                ^
fail_compilation/testInference.d(244): Error: `pure` function `testInference.test13729a` cannot call impure function `testInference.test13729a.foo`
    foo();              // cannot call impure function
       ^
fail_compilation/testInference.d(242):        which wasn't inferred `pure` because of:
        g13729++;
        ^
fail_compilation/testInference.d(242):        `pure` function `testInference.test13729a.foo` cannot access mutable static data `g13729`
fail_compilation/testInference.d(252): Error: `pure` function `testInference.test13729b` cannot call impure function `testInference.test13729b.foo!().foo`
    foo();              // cannot call impure function
       ^
fail_compilation/testInference.d(250):        which wasn't inferred `pure` because of:
        g13729++;
        ^
fail_compilation/testInference.d(250):        `pure` function `testInference.test13729b.foo!().foo` cannot access mutable static data `g13729`
fail_compilation/testInference.d(261): Error: `testInference.test17086` called with argument types `(bool)` matches both:
fail_compilation/testInference.d(255):     `testInference.test17086!(bool, false).test17086(bool x)`
and:
fail_compilation/testInference.d(256):     `testInference.test17086!(bool, false).test17086(bool y)`
    test17086(f);
             ^
fail_compilation/testInference.d(269): Error: `pure` function `testInference.test20047_pure_function` cannot call impure function `testInference.test20047_pure_function.bug`
    bug();
       ^
fail_compilation/testInference.d(268):        which calls `testInference.test20047_impure_function`
    static void bug() { return test20047_impure_function(); }
                                                        ^
---
*/

class A8998
{
    int i;
}
class C8998
{
    A8998 a;

    this()
    {
        a = new A8998();
    }

    // WRONG: Returns immutable(A8998)
    immutable(A8998) get() inout pure
    {
        return a;   // should be error
    }
}

string foo(in char[] s) pure
{
    return s;   //
}
immutable(int[]) x1() /*pure*/
{
    int[] a = new int[](10);
    return a;   //
}
immutable(int[]) x2(int len) /*pure*/
{
    int[] a = new int[](len);
    return a;
}
immutable(int[]) x3(immutable(int[]) org) /*pure*/
{
    int[] a = new int[](org.length);
    return a;   //
}

immutable(Object) get(inout int*) pure
{
    auto o = new Object;
    return o;   // should be ok
}
immutable(Object) get(immutable Object) pure
{
    auto o = new Object;
    return o;   // should be ok
}
inout(Object) get(inout Object) pure
{
    auto o = new Object;
    return o;   // should be ok (, but cannot in current conservative rule)
}

class C1 { C2 c2; }
class C2 { C3 c3; }
class C3 { C1 c1; }
immutable(C1) recursive1(C3 pc) pure { auto c = new C1(); return c; }   // should be error, because pc.c1 == C1
immutable(C1) recursive2(C2 pc) pure { auto c = new C1(); return c; }   // should be error, because pc.c3.c1 == C1
immutable(C3) recursive3(C1 pc) pure { auto c = new C3(); return c; }   // should be error, c.c1 may be pc
immutable(C3) recursive4(C2 pc) pure { auto c = new C3(); return c; }   // should be error, c.c1.c2 may be pc
immutable(C1) recursive5(shared C2 pc) pure { auto c = new C1(); return c; }
immutable(C1) recursive6(immutable C2 pc) pure { auto c = new C1(); return c; }
immutable(C1) recursiveE(immutable C2 pc) pure { auto c = new X1(); return c; }

class C4 { C4[] arr; }
immutable(C4)[] recursive7(int[] arr) pure { auto a = new C4[](1); return a; }

struct S1 { int* ptr; }
immutable(S1)     foo1a(          int*[] prm) pure {                S1 s; return s; }   // NG
immutable(S1)     foo1b(    const int*[] prm) pure {                S1 s; return s; }   // OK
immutable(S1)     foo1c(immutable int*[] prm) pure {                S1 s; return s; }   // OK
immutable(int*[]) bar1a(              S1 prm) pure {           int *[] a; return a; }   // NG
immutable(int*[]) bar1b(              S1 prm) pure {     const(int)*[] a; return a; }   // NG
immutable(int*[]) bar1c(              S1 prm) pure { immutable(int)*[] a; return a; }   // OK

struct S2 { const(int)* ptr; }
immutable(S2)     foo2a(          int*[] prm) pure {                S2 s; return s; }   // OK
immutable(S2)     foo2b(    const int*[] prm) pure {                S2 s; return s; }   // NG
immutable(S2)     foo2c(immutable int*[] prm) pure {                S2 s; return s; }   // NG
immutable(int*[]) bar2a(              S2 prm) pure {           int *[] a; return a; }   // OK
immutable(int*[]) bar2b(              S2 prm) pure {     const(int)*[] a; return a; }   // NG
immutable(int*[]) bar2c(              S2 prm) pure { immutable(int)*[] a; return a; }   // OK


inout(void)* f10063(inout void* p) pure
{
    return p;
}
immutable(void)* g10063(inout int* p) pure
{
    return f10063(p);
}

// Line 143 starts here
auto impure14049() { static int i = 1; return i; }

void foo14049(T)(T val)
{
    auto n = () @trusted {
        return impure14049();
    }();
}

void bar14049() pure
{
    foo14049(1);
}

int g14160;
int* f14160() pure
{
    return &g14160; // should be rejected
}

// Line 175 starts here
int g12422;
void foo12422() { ++g12422; }
void test12422() pure
{
    void bar12422()() { foo12422(); }
    bar12422();
}

// Line 190 starts here
int g13729;

void test13729a() pure
{
    static void foo()   // typed as impure
    {
        g13729++;
    }
    foo();              // cannot call impure function
}
void test13729b() pure
{
    static void foo()() // inferred to impure
    {
        g13729++;
    }
    foo();              // cannot call impure function
}

void test17086 (T, T V = T.init) (T x) { assert(x.foo); }
void test17086 (T, T V = T.init) (T y) { assert(y.bar); }

void test17086_call ()
{
    bool f;
    test17086(f);
}

// Line 234 starts here
void test20047_impure_function() {}
void test20047_pure_function() pure
{
    static void bug() { return test20047_impure_function(); }
    bug();
}
