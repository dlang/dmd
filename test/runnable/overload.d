// EXTRA_SOURCES: imports/ovs1528a.d imports/ovs1528b.d
// EXTRA_SOURCES: imports/template_ovs1.d imports/template_ovs2.d imports/template_ovs3.d

import imports.template_ovs1;
import imports.template_ovs2;
import imports.template_ovs3;

extern(C) int printf(const char* fmt, ...);

template TypeTuple(T...){ alias T TypeTuple; }
template Id(      T){ alias T Id; }
template Id(alias A){ alias A Id; }

/***************************************************/
// 1528

int foo1528(long){ return 1; }
int foo1528(int[]){ return 2; }
int foo1528(T)(T) if ( is(T:real)) { return 3; }
int foo1528(T)(T) if (!is(T:real)) { return 4; }
int bar1528(T)(T) if (!is(T:real)) { return 4; }
int bar1528(T)(T) if ( is(T:real)) { return 3; }
int bar1528(int[]){ return 2; }
int bar1528(long){ return 1; }

@property auto getfoo1528   () { return 1; }
@property auto getfoo1528(T)() { return 2; }
@property auto getbar1528(T)() { return 2; }
@property auto getbar1528   () { return 1; }

@property auto setfoo1528   (int) { return 1; }
@property auto setfoo1528(T)(int) { return 2; }
@property auto setbar1528(T)(int) { return 2; }
@property auto setbar1528   (int) { return 1; }

struct S1528
{
    int foo(long){ return 1; }
    int foo(int[]){ return 2; }
    int foo(T)(T) if ( is(T:real)) { return 3; }
    int foo(T)(T) if (!is(T:real)) { return 4; }
    int bar(T)(T) if (!is(T:real)) { return 4; }
    int bar(T)(T) if ( is(T:real)) { return 3; }
    int bar(int[]){ return 2; }
    int bar(long){ return 1; }

    @property auto getfoo   () { return 1; }
    @property auto getfoo(T)() { return 2; }
    @property auto getbar(T)() { return 2; }
    @property auto getbar   () { return 1; }

    @property auto setfoo   (int) { return 1; }
    @property auto setfoo(T)(int) { return 2; }
    @property auto setbar(T)(int) { return 2; }
    @property auto setbar   (int) { return 1; }

    @property auto propboo   ()    { return 1; }
    @property auto propboo(T)(T)   { return 2; }
    @property auto propbaz(T)(T)   { return 2; }
    @property auto propbaz   ()    { return 1; }
}

auto ufoo1528   (S1528) { return 1; }
auto ufoo1528(T)(S1528) { return 2; }
auto ubar1528(T)(S1528) { return 2; }
auto ubar1528   (S1528) { return 1; }

@property auto ugetfoo1528   (S1528) { return 1; }
@property auto ugetfoo1528(T)(S1528) { return 2; }
@property auto ugetbar1528(T)(S1528) { return 2; }
@property auto ugetbar1528   (S1528) { return 1; }

@property auto usetfoo1528   (S1528, int) { return 1; }
@property auto usetfoo1528(T)(S1528, int) { return 2; }
@property auto usetbar1528(T)(S1528, int) { return 2; }
@property auto usetbar1528   (S1528, int) { return 1; }

@property auto upropboo1528   (S1528)      { return 1; }
@property auto upropboo1528(T)(S1528, T)   { return 2; }
@property auto upropbaz1528(T)(S1528, T)   { return 2; }
@property auto upropbaz1528   (S1528)      { return 1; }

void test1528a()
{
    // global
    assert(foo1528(100) == 1);
    assert(foo1528(10L) == 1);
    assert(foo1528([1]) == 2);
    assert(foo1528(1.0) == 3);
    assert(foo1528("a") == 4);
    assert(bar1528(100) == 1);
    assert(bar1528(10L) == 1);
    assert(bar1528([1]) == 2);
    assert(bar1528(1.0) == 3);
    assert(bar1528("a") == 4);

    assert(getfoo1528        == 1);
    assert(getfoo1528!string == 2);
    assert(getbar1528        == 1);
    assert(getbar1528!string == 2);

    assert((setfoo1528        = 1) == 1);
    assert((setfoo1528!string = 1) == 2);
    assert((setbar1528        = 1) == 1);
    assert((setbar1528!string = 1) == 2);

    S1528 s;

    // member
    assert(s.foo(100) == 1);
    assert(s.foo(10L) == 1);
    assert(s.foo([1]) == 2);
    assert(s.foo(1.0) == 3);
    assert(s.foo("a") == 4);
    assert(s.bar(100) == 1);
    assert(s.bar(10L) == 1);
    assert(s.bar([1]) == 2);
    assert(s.bar(1.0) == 3);
    assert(s.bar("a") == 4);

    assert(s.getfoo        == 1);
    assert(s.getfoo!string == 2);
    assert(s.getbar        == 1);
    assert(s.getbar!string == 2);

    assert((s.setfoo        = 1) == 1);
    assert((s.setfoo!string = 1) == 2);
    assert((s.setbar        = 1) == 1);
    assert((s.setbar!string = 1) == 2);

    assert((s.propboo = 1) == 2);
    assert( s.propboo      == 1);
    assert((s.propbaz = 1) == 2);
    assert( s.propbaz      == 1);

    // UFCS
    assert(s.ufoo1528       () == 1);
    assert(s.ufoo1528!string() == 2);
    assert(s.ubar1528       () == 1);
    assert(s.ubar1528!string() == 2);

    assert(s.ugetfoo1528        == 1);
    assert(s.ugetfoo1528!string == 2);
    assert(s.ugetbar1528        == 1);
    assert(s.ugetbar1528!string == 2);

    assert((s.usetfoo1528        = 1) == 1);
    assert((s.usetfoo1528!string = 1) == 2);
    assert((s.usetbar1528        = 1) == 1);
    assert((s.usetbar1528!string = 1) == 2);

    assert((s.upropboo1528 = 1) == 2);
    assert( s.upropboo1528      == 1);
    assert((s.upropbaz1528 = 1) == 2);
    assert( s.upropbaz1528      == 1);

    // overload set
    import imports.ovs1528a, imports.ovs1528b;
    assert(func1528()    == 1);
    assert(func1528(1.0) == 2);
    assert(func1528("a") == 3);
    assert(func1528([1.0]) == 4);
    assert(bunc1528()    == 1);
    assert(bunc1528(1.0) == 2);
    assert(bunc1528("a") == 3);
    assert(bunc1528([1.0]) == 4);

    assert(vunc1528(100) == 1);
    assert(vunc1528("a") == 2);
    assert(wunc1528(100) == 1);
    assert(wunc1528("a") == 2);

    //assert(opUnary1528!"+"(10) == 1);
    //assert(opUnary1528!"-"(10) == 2);
}

// ----

int doo1528a(int a, double=10) { return 1; }
int doo1528a(int a, string="") { return 2; }

int doo1528b(int a) { return 1; }
int doo1528b(T:int)(T b) { return 2; }

int doo1528c(T:int)(T b, double=10) { return 2; }
int doo1528c(T:int)(T b, string="") { return 2; }

int doo1528d(int a) { return 1; }
int doo1528d(T)(T b) { return 2; }

void test1528b()
{
    // MatchLevel by tiargs     / by fargs
    static assert(!__traits(compiles, doo1528a(1)));
            // 1: MATCHexact    / MATCHexact
            // 2: MATCHexact    / MATCHexact
    static assert(!__traits(compiles, doo1528a(1L)));
            // 1: MATCHexact    / MATCHconvert
            // 2: MATCHexact    / MATCHconvert

    static assert(!__traits(compiles, doo1528b(1)));
            // 1: MATCHexact    / MATCHexact
            // 2: MATCHexact    / MATCHexact
    assert(doo1528b(1L) == 1);
            // 1: MATCHexact    / MATCHconvert
            // 2: MATCHnomatch  / -

    static assert(!__traits(compiles, doo1528c(1)));
            // 1: MATCHexact    / MATCHexact
            // 2: MATCHexact    / MATCHexact
    static assert(!__traits(compiles, doo1528c(1L)));
            // 1: MATCHnomatch  / -
            // 2: MATCHnomatch  / -

    assert(doo1528d(1) == 1);
            // 1: MATCHexact    / MATCHexact
            // 2: MATCHconvert  / MATCHexact
    assert(doo1528d(1L) == 1);
            // 1: MATCHexact    / MATCHconvert
            // 2: MATCHconvert  / MATCHexact
            // -> not sure, may be ambiguous...?
}

// ----

char[num*2] toHexString1528(int order, size_t num)(in ubyte[num] digest) { return typeof(return).init; }
     string toHexString1528(int order)(in ubyte[] digest) { assert(0); }

char[8] test1528c()
{
    ubyte[4] foo() { return typeof(return).init; }
    return toHexString1528!10(foo);
}

// ----

int f1528d1(int a, double=10) { return 1; }
int f1528d1(int a, string="") { return 2; }

int f1528d2(T:int)(T b, double=10) { return 1; }
int f1528d2(T:int)(T b, string="") { return 2; }

// vs deduced parameter
int f1528d3(int a) { return 1; }
int f1528d3(T)(T b) { return 2; }

// vs specialized parameter
int f1528d4(int a) { return 1; }
int f1528d4(T:int)(T b) { return 2; }

// vs deduced parameter + template constraint (1)
int f1528d5(int a) { return 1; }
int f1528d5(T)(T b) if (is(T == int)) { return 2; }

// vs deduced parameter + template constraint (2)
int f1528d6(int a) { return 1; }
int f1528d6(T)(T b) if (is(T : int)) { return 2; }

// vs nallowing conversion
int f1528d7(ubyte a) { return 1; }
int f1528d7(T)(T b) if (is(T : int)) { return 2; }

int f1528d10(int, int) { return 1; }
int f1528d10(T)(T, int) { return 2; }

void test1528d()
{
    static assert(!__traits(compiles, f1528d1(1)));  // ambiguous
    static assert(!__traits(compiles, f1528d1(1L))); // ambiguous

    static assert(!__traits(compiles, f1528d2(1)));  // ambiguous
    static assert(!__traits(compiles, f1528d2(1L))); // no match

    assert(f1528d3(1) == 1);
    assert(f1528d3(1L) == 1);    // '1L' matches int
    short short_val = 42;
    assert(f1528d3(cast(short) 42) == 1);
    assert(f1528d3(short_val) == 1);

    static assert(!__traits(compiles, f1528d4(1)));
    assert(f1528d4(1L) == 1);

    assert(f1528d5(1) == 1);
    assert(f1528d5(1L) == 1);

    assert(f1528d6(1) == 1);
    assert(f1528d6(1L) == 1);
    static assert(!__traits(compiles, f1528d6(ulong.max))); // no match
                                          // needs to fix bug 9617
    ulong ulval = 1;
    static assert(!__traits(compiles, f1528d6(ulval)));     // no match

    assert(f1528d7(200u) == 1);  // '200u' matches ubyte
    assert(f1528d7(400u) == 2);
    uint uival = 400;       // TDPL-like range knowledge lost here.
    assert(f1528d7(uival) == 2);
    uival = 200;            // Ditto.
    assert(f1528d7(uival) == 2);


    assert(f1528d10(        1, 9) == 1);
    assert(f1528d10(       1U, 9) == 1);
    assert(f1528d10(       1L, 9) == 1);
    assert(f1528d10(      1LU, 9) == 1);
    assert(f1528d10( long.max, 9) == 2);
    assert(f1528d10(ulong.max, 9) == 2);
    assert(f1528d10(        1, 9L) == 1);
    assert(f1528d10(       1U, 9L) == 1);
    assert(f1528d10(       1L, 9L) == 1);
    assert(f1528d10(      1LU, 9L) == 1);
    assert(f1528d10( long.max, 9L) == 2);
    assert(f1528d10(ulong.max, 9L) == 2);
}

/***************************************************/
// 1680

struct S1680
{
    ulong _y;

           ulong blah1()        { return _y; }
    static S1680 blah1(ulong n) { return S1680(n); }

    static S1680 blah2(ulong n)  { return S1680(n); }
    static S1680 blah2(char[] n) { return S1680(n.length); }
}

class C1680
{
    ulong _y;
    this(ulong n){}

           ulong blah1()        { return _y; }
    static C1680 blah1(ulong n) { return new C1680(n); }

    static C1680 blah2(ulong n)  { return new C1680(n); }
    static C1680 blah2(char[] n) { return new C1680(n.length); }
}

void test1680()
{
    // OK
    S1680 s = S1680.blah1(5);
    void fs()
    {
        S1680 s1 = S1680.blah2(5);              // OK
        S1680 s2 = S1680.blah2("hello".dup);    // OK
        S1680 s3 = S1680.blah1(5);
        // Error: 'this' is only allowed in non-static member functions, not f
    }

    C1680 c = C1680.blah1(5);
    void fc()
    {
        C1680 c1 = C1680.blah2(5);
        C1680 c2 = C1680.blah2("hello".dup);
        C1680 c3 = C1680.blah1(5);
    }
}

/***************************************************/
// 7418

int foo7418(uint a)   { return 1; }
int foo7418(char[] a) { return 2; }

alias foo7418 foo7418a;
template foo7418b(T = void) { alias foo7418 foo7418b; }

void test7418()
{
    assert(foo7418a(1U) == 1);
    assert(foo7418a("a".dup) == 2);

    assert(foo7418b!()(1U) == 1);
    assert(foo7418b!()("a".dup) == 2);
}

/***************************************************/
// 7552

struct S7552
{
    static void foo(){}
    static void foo(int){}
}

struct T7552
{
    alias TypeTuple!(__traits(getOverloads, S7552, "foo")) FooInS;
    alias FooInS[0] foo;    // should be S7552.foo()
    static void foo(string){}
}

struct U7552
{
    alias TypeTuple!(__traits(getOverloads, S7552, "foo")) FooInS;
    alias FooInS[1] foo;    // should be S7552.foo(int)
    static void foo(string){}
}

void test7552()
{
    alias TypeTuple!(__traits(getOverloads, S7552, "foo")) FooInS;
    static assert(FooInS.length == 2);
                                      FooInS[0]();
    static assert(!__traits(compiles, FooInS[0](0)));
    static assert(!__traits(compiles, FooInS[1]()));
                                      FooInS[1](0);

                                      Id!(FooInS[0])();
    static assert(!__traits(compiles, Id!(FooInS[0])(0)));
    static assert(!__traits(compiles, Id!(FooInS[1])()));
                                      Id!(FooInS[1])(0);

    alias TypeTuple!(__traits(getOverloads, T7552, "foo")) FooInT;
    static assert(FooInT.length == 2);                  // fail
                                      FooInT[0]();
    static assert(!__traits(compiles, FooInT[0](0)));
    static assert(!__traits(compiles, FooInT[0]("")));
    static assert(!__traits(compiles, FooInT[1]()));
    static assert(!__traits(compiles, FooInT[1](0)));   // fail
                                      FooInT[1]("");    // fail

    alias TypeTuple!(__traits(getOverloads, U7552, "foo")) FooInU;
    static assert(FooInU.length == 2);
    static assert(!__traits(compiles, FooInU[0]()));
                                      FooInU[0](0);
    static assert(!__traits(compiles, FooInU[0]("")));
    static assert(!__traits(compiles, FooInU[1]()));
    static assert(!__traits(compiles, FooInU[1](0)));
                                      FooInU[1]("");
}

/***************************************************/
// 8668

import imports.m8668a;
import imports.m8668c; //replace with m8668b to make it work

void test8668()
{
    split8668("abc");
    split8668(123);
}

/***************************************************/
// 8943

void test8943()
{
    struct S
    {
        void foo();
    }

    alias TypeTuple!(__traits(getOverloads, S, "foo")) Overloads;
    alias TypeTuple!(__traits(parent, Overloads[0])) P; // fail
    static assert(is(P[0] == S));
}

/***************************************************/
// 9410

struct S {}
int foo(float f, ref S s) { return 1; }
int foo(float f,     S s) { return 2; }
void test9410()
{
    S s;
    assert(foo(1, s  ) == 1); // works fine. Print: ref
    assert(foo(1, S()) == 2); // Fails with: Error: S() is not an lvalue
}

/***************************************************/
// 10171

struct B10171(T) { static int x; }

void test10171()
{
    auto mp = &B10171!(B10171!int).x;
}

/***************************************************/
// 1900 - template overload set

void test1900a()
{
    // function vs function template with IFTI call
    assert(foo1900a(100) == 1);
    assert(foo1900a("s") == 2);
    assert(foo1900b(100) == 1);
    assert(foo1900b("s") == 2);
    // function template call with explicit template arguments
    assert(foo1900a!string("s") == 2);
    assert(foo1900b!string("s") == 2);

    // function template overloaded set call with IFTI
    assert(bar1900a(100) == 1);
    assert(bar1900a("s") == 2);
    assert(bar1900b(100) == 1);
    assert(bar1900b("s") == 2);
    // function template overloaded set call with explicit template arguments
    assert(bar1900a!double(100) == 1);
    assert(bar1900a!string("s") == 2);
    assert(bar1900b!double(100) == 1);
    assert(bar1900b!string("s") == 2);

    // function template overloaded set call with IFTI
    assert(baz1900(1234567890) == 1);
    assert(baz1900([1:1, 2:2]) == 2);
    assert(baz1900(new Object) == 3);
    assert(baz1900("deadbeaf") == 4);
    // function template overloaded set call with explicit template arguments
    assert(baz1900!(double)(14142135) == 1);
    assert(baz1900!(int[int])([12:34]) == 2);
    assert(baz1900!(Object)(new Object) == 3);
    assert(baz1900!(string)("cafe babe") == 4);

    static assert(!__traits(compiles, bad1900!"++"()));
}

void test1900b()
{
    S1900 s;

    // function vs function template with IFTI call
    assert(s.foo1900a(100) == 1);
    assert(s.foo1900a("s") == 2);
    assert(s.foo1900b(100) == 1);
    assert(s.foo1900b("s") == 2);
    // function template call with explicit template arguments
    assert(s.foo1900a!string("s") == 2);
    assert(s.foo1900b!string("s") == 2);

    // function template overloaded set call with IFTI
    assert(s.bar1900a(100) == 1);
    assert(s.bar1900a("s") == 2);
    assert(s.bar1900b(100) == 1);
    assert(s.bar1900b("s") == 2);
    // function template overloaded set call with explicit template arguments
    assert(s.bar1900a!double(100) == 1);
    assert(s.bar1900a!string("s") == 2);
    assert(s.bar1900b!double(100) == 1);
    assert(s.bar1900b!string("s") == 2);

    // function template overloaded set call with IFTI
    assert(s.baz1900(1234567890) == 1);
    assert(s.baz1900([1:1, 2:2]) == 2);
    assert(s.baz1900(new Object) == 3);
    assert(s.baz1900("deadbeaf") == 4);
    // function template overloaded set call with explicit template arguments
    assert(s.baz1900!(double)(14142135) == 1);
    assert(s.baz1900!(int[int])([12:34]) == 2);
    assert(s.baz1900!(Object)(new Object) == 3);
    assert(s.baz1900!(string)("cafe babe") == 4);

    static assert(!__traits(compiles, s.bad1900!"++"()));
}

void test1900c()
{
    S1900 s;

    // This is a kind of Issue 1528 - [tdpl] overloading template and non-template functions
    //s.funca();
    //s.funca(10);
    //s.funcb();
    //s.funcb(10);

    // Call function template overload set through mixin member lookup
    assert(s.mixfooa() == 1);
    assert(s.mixfooa(10) == 2);
    assert(s.mixfoob() == 1);
    assert(s.mixfoob(10) == 2);

    // Call function template overload set through mixin^2 member lookup
    assert(s.mixsubfooa() == 1);
    assert(s.mixsubfooa(10) == 2);
    assert(s.mixsubfoob() == 1);
    assert(s.mixsubfoob(10) == 2);

    // Using mixin identifier can limit overload set
    assert(s.a.mixfooa() == 1);     static assert(!__traits(compiles, s.a.mixfooa(10)));
    assert(s.b.mixfooa(10) == 2);   static assert(!__traits(compiles, s.b.mixfooa()));
    assert(s.b.mixfoob() == 1);     static assert(!__traits(compiles, s.b.mixfoob(10)));
    assert(s.a.mixfoob(10) == 2);   static assert(!__traits(compiles, s.a.mixfoob()));
}

version(none)   // yet not implemented
{
alias merge1900 = imports.template_ovs1.merge1900;
alias merge1900 = imports.template_ovs2.merge1900;

void test1900d()
{
    assert( merge1900!double(100) == 1);
    assert(.merge1900!double(100) == 1);
}
}
else
{
void test1900d() {} // dummy
}

mixin template Foo1900e(T)
{
    void foo(U : T)() { v++;}
}
void test1900e()
{
    struct S
    {
        int v;
        mixin Foo1900e!double;
        mixin Foo1900e!string;
        void test()
        {
            foo!(int);          // ScopeExp(ti->tempovers != NULL)
            foo!(typeof(null)); // ScopeExp(ti->tempovers != NULL)
        }
    }

    S s;
    assert(s.v == 0);
    s.test();
    assert(s.v == 2);
}

/***************************************************/
// 1900

void test1900()
{
    AClass1900 a;
    BClass1900 b;

    static assert(Traits1900!(AClass1900).name == "AClass");
    static assert(Traits1900!(BClass1900).name == "BClass");
    static assert(Traits1900!(int).name == "any");

    Traits1900!(long) obj;
}

version(none)   // yet not implemented
{
alias imports.template_ovs1.Traits1900 Traits1900X;
alias imports.template_ovs2.Traits1900 Traits1900X;
alias imports.template_ovs3.Traits1900 Traits1900X;
static assert(Traits1900X!(AClass1900).name == "AClass");
static assert(Traits1900X!(BClass1900).name == "BClass");
static assert(Traits1900X!(int).name == "any");

// Traits1900Y is exact same as imports.template_ovs1.Traits1900.
alias imports.template_ovs1.Traits1900 Traits1900Y1;
alias imports.template_ovs1.Traits1900 Traits1900Y2;
alias Traits1900Y1 Traits1900Y;
alias Traits1900Y2 Traits1900Y;
static assert(Traits1900Y!(AClass1900).name == "AClass");
static assert(!__traits(compiles, Traits1900Y!(BClass1900)));
static assert(!__traits(compiles, Traits1900Y!(int)));
}

template Foo1900(T)
{
    template Bar1900(U : T)
    {
    }
}
mixin Foo1900!(int) A;
mixin Foo1900!(char) B;
alias Bar1900!(int) bar;    //error

/***************************************************/

int main()
{
    test1528a();
    test1528b();
    test1528c();
    test1528d();
    test1680();
    test7418();
    test7552();
    test8668();
    test8943();
    test9410();
    test10171();
    test1900a();
    test1900b();
    test1900c();
    test1900d();
    test1900e();

    printf("Success\n");
    return 0;
}
