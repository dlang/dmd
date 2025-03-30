/*
PERMUTE_ARGS:
EXTRA_FILES: imports/a9546.d

Windows linker may write something like:
---
Creating library {{RESULTS_DIR}}/runnable/traits_0.lib and object {{RESULTS_DIR}}/runnable/traits_0.exp
---

TRANSFORM_OUTPUT: remove_lines("Creating library")
TEST_OUTPUT:
---
__lambda_L1073_C5
---
*/

module traits;

import core.stdc.stdio;

alias int myint;
struct S { void bar() { } int x = 4; static int z = 5; }
class C { void bar() { } final void foo() { } static void abc() { } }
abstract class AC { }
class AC2 { abstract void foo(); }
class AC3 : AC2 { }
final class FC { void foo() { } }
enum E { EMEM }
struct D1 { @disable void true_(); void false_(){} }

/********************************************************/

void test1()
{
    auto t = __traits(isArithmetic, int);
    assert(t == true);

    assert(__traits(isArithmetic) == false);
    assert(__traits(isArithmetic, myint) == true);
    assert(__traits(isArithmetic, S) == false);
    assert(__traits(isArithmetic, C) == false);
    assert(__traits(isArithmetic, E) == true);
    assert(__traits(isArithmetic, void*) == false);
    assert(__traits(isArithmetic, void[]) == false);
    assert(__traits(isArithmetic, void[3]) == false);
    assert(__traits(isArithmetic, int[char]) == false);
    assert(__traits(isArithmetic, int, int) == true);
    assert(__traits(isArithmetic, int, S) == false);

    assert(__traits(isArithmetic, void) == false);
    assert(__traits(isArithmetic, byte) == true);
    assert(__traits(isArithmetic, ubyte) == true);
    assert(__traits(isArithmetic, short) == true);
    assert(__traits(isArithmetic, ushort) == true);
    assert(__traits(isArithmetic, int) == true);
    assert(__traits(isArithmetic, uint) == true);
    assert(__traits(isArithmetic, long) == true);
    assert(__traits(isArithmetic, ulong) == true);
    assert(__traits(isArithmetic, float) == true);
    assert(__traits(isArithmetic, double) == true);
    assert(__traits(isArithmetic, real) == true);
    assert(__traits(isArithmetic, char) == true);
    assert(__traits(isArithmetic, wchar) == true);
    assert(__traits(isArithmetic, dchar) == true);

    int i;
    assert(__traits(isArithmetic, i, i+1, int) == true);
    assert(__traits(isArithmetic) == false);
}

/********************************************************/

void test2()
{
    auto t = __traits(isScalar, int);
    assert(t == true);

    assert(__traits(isScalar) == false);
    assert(__traits(isScalar, myint) == true);
    assert(__traits(isScalar, S) == false);
    assert(__traits(isScalar, C) == false);
    assert(__traits(isScalar, E) == true);
    assert(__traits(isScalar, void*) == true);
    assert(__traits(isScalar, void[]) == false);
    assert(__traits(isScalar, void[3]) == false);
    assert(__traits(isScalar, int[char]) == false);
    assert(__traits(isScalar, int, int) == true);
    assert(__traits(isScalar, int, S) == false);

    assert(__traits(isScalar, void) == false);
    assert(__traits(isScalar, byte) == true);
    assert(__traits(isScalar, ubyte) == true);
    assert(__traits(isScalar, short) == true);
    assert(__traits(isScalar, ushort) == true);
    assert(__traits(isScalar, int) == true);
    assert(__traits(isScalar, uint) == true);
    assert(__traits(isScalar, long) == true);
    assert(__traits(isScalar, ulong) == true);
    assert(__traits(isScalar, float) == true);
    assert(__traits(isScalar, double) == true);
    assert(__traits(isScalar, real) == true);
    assert(__traits(isScalar, char) == true);
    assert(__traits(isScalar, wchar) == true);
    assert(__traits(isScalar, dchar) == true);
}

/********************************************************/

void test3()
{
    assert(__traits(isIntegral) == false);
    assert(__traits(isIntegral, myint) == true);
    assert(__traits(isIntegral, S) == false);
    assert(__traits(isIntegral, C) == false);
    assert(__traits(isIntegral, E) == true);
    assert(__traits(isIntegral, void*) == false);
    assert(__traits(isIntegral, void[]) == false);
    assert(__traits(isIntegral, void[3]) == false);
    assert(__traits(isIntegral, int[char]) == false);
    assert(__traits(isIntegral, int, int) == true);
    assert(__traits(isIntegral, int, S) == false);

    assert(__traits(isIntegral, void) == false);
    assert(__traits(isIntegral, byte) == true);
    assert(__traits(isIntegral, ubyte) == true);
    assert(__traits(isIntegral, short) == true);
    assert(__traits(isIntegral, ushort) == true);
    assert(__traits(isIntegral, int) == true);
    assert(__traits(isIntegral, uint) == true);
    assert(__traits(isIntegral, long) == true);
    assert(__traits(isIntegral, ulong) == true);
    assert(__traits(isIntegral, float) == false);
    assert(__traits(isIntegral, double) == false);
    assert(__traits(isIntegral, real) == false);
    assert(__traits(isIntegral, char) == true);
    assert(__traits(isIntegral, wchar) == true);
    assert(__traits(isIntegral, dchar) == true);
}

/********************************************************/

void test4()
{
    assert(__traits(isFloating) == false);
    assert(__traits(isFloating, S) == false);
    assert(__traits(isFloating, C) == false);
    assert(__traits(isFloating, E) == false);
    assert(__traits(isFloating, void*) == false);
    assert(__traits(isFloating, void[]) == false);
    assert(__traits(isFloating, void[3]) == false);
    assert(__traits(isFloating, int[char]) == false);
    assert(__traits(isFloating, float, float) == true);
    assert(__traits(isFloating, float, S) == false);

    assert(__traits(isFloating, void) == false);
    assert(__traits(isFloating, byte) == false);
    assert(__traits(isFloating, ubyte) == false);
    assert(__traits(isFloating, short) == false);
    assert(__traits(isFloating, ushort) == false);
    assert(__traits(isFloating, int) == false);
    assert(__traits(isFloating, uint) == false);
    assert(__traits(isFloating, long) == false);
    assert(__traits(isFloating, ulong) == false);
    assert(__traits(isFloating, float) == true);
    assert(__traits(isFloating, double) == true);
    assert(__traits(isFloating, real) == true);
    assert(__traits(isFloating, char) == false);
    assert(__traits(isFloating, wchar) == false);
    assert(__traits(isFloating, dchar) == false);
}

/********************************************************/

void test5()
{
    assert(__traits(isUnsigned) == false);
    assert(__traits(isUnsigned, S) == false);
    assert(__traits(isUnsigned, C) == false);
    assert(__traits(isUnsigned, E) == false);
    assert(__traits(isUnsigned, void*) == false);
    assert(__traits(isUnsigned, void[]) == false);
    assert(__traits(isUnsigned, void[3]) == false);
    assert(__traits(isUnsigned, int[char]) == false);
    assert(__traits(isUnsigned, float, float) == false);
    assert(__traits(isUnsigned, float, S) == false);

    assert(__traits(isUnsigned, void) == false);
    assert(__traits(isUnsigned, byte) == false);
    assert(__traits(isUnsigned, ubyte) == true);
    assert(__traits(isUnsigned, short) == false);
    assert(__traits(isUnsigned, ushort) == true);
    assert(__traits(isUnsigned, int) == false);
    assert(__traits(isUnsigned, uint) == true);
    assert(__traits(isUnsigned, long) == false);
    assert(__traits(isUnsigned, ulong) == true);
    assert(__traits(isUnsigned, float) == false);
    assert(__traits(isUnsigned, double) == false);
    assert(__traits(isUnsigned, real) == false);
    assert(__traits(isUnsigned, char) == true);
    assert(__traits(isUnsigned, wchar) == true);
    assert(__traits(isUnsigned, dchar) == true);
}

/********************************************************/

void test6()
{
    assert(__traits(isAssociativeArray) == false);
    assert(__traits(isAssociativeArray, S) == false);
    assert(__traits(isAssociativeArray, C) == false);
    assert(__traits(isAssociativeArray, E) == false);
    assert(__traits(isAssociativeArray, void*) == false);
    assert(__traits(isAssociativeArray, void[]) == false);
    assert(__traits(isAssociativeArray, void[3]) == false);
    assert(__traits(isAssociativeArray, int[char]) == true);
    assert(__traits(isAssociativeArray, float, float) == false);
    assert(__traits(isAssociativeArray, float, S) == false);

    assert(__traits(isAssociativeArray, void) == false);
    assert(__traits(isAssociativeArray, byte) == false);
    assert(__traits(isAssociativeArray, ubyte) == false);
    assert(__traits(isAssociativeArray, short) == false);
    assert(__traits(isAssociativeArray, ushort) == false);
    assert(__traits(isAssociativeArray, int) == false);
    assert(__traits(isAssociativeArray, uint) == false);
    assert(__traits(isAssociativeArray, long) == false);
    assert(__traits(isAssociativeArray, ulong) == false);
    assert(__traits(isAssociativeArray, float) == false);
    assert(__traits(isAssociativeArray, double) == false);
    assert(__traits(isAssociativeArray, real) == false);
    assert(__traits(isAssociativeArray, char) == false);
    assert(__traits(isAssociativeArray, wchar) == false);
    assert(__traits(isAssociativeArray, dchar) == false);
}

/********************************************************/

void test7()
{
    assert(__traits(isStaticArray) == false);
    assert(__traits(isStaticArray, S) == false);
    assert(__traits(isStaticArray, C) == false);
    assert(__traits(isStaticArray, E) == false);
    assert(__traits(isStaticArray, void*) == false);
    assert(__traits(isStaticArray, void[]) == false);
    assert(__traits(isStaticArray, void[3]) == true);
    assert(__traits(isStaticArray, int[char]) == false);
    assert(__traits(isStaticArray, float, float) == false);
    assert(__traits(isStaticArray, float, S) == false);

    assert(__traits(isStaticArray, void) == false);
    assert(__traits(isStaticArray, byte) == false);
    assert(__traits(isStaticArray, ubyte) == false);
    assert(__traits(isStaticArray, short) == false);
    assert(__traits(isStaticArray, ushort) == false);
    assert(__traits(isStaticArray, int) == false);
    assert(__traits(isStaticArray, uint) == false);
    assert(__traits(isStaticArray, long) == false);
    assert(__traits(isStaticArray, ulong) == false);
    assert(__traits(isStaticArray, float) == false);
    assert(__traits(isStaticArray, double) == false);
    assert(__traits(isStaticArray, real) == false);
    assert(__traits(isStaticArray, char) == false);
    assert(__traits(isStaticArray, wchar) == false);
    assert(__traits(isStaticArray, dchar) == false);
}

/********************************************************/

void test8()
{
    assert(__traits(isAbstractClass) == false);
    assert(__traits(isAbstractClass, S) == false);
    assert(__traits(isAbstractClass, C) == false);
    assert(__traits(isAbstractClass, AC) == true);
    assert(__traits(isAbstractClass, E) == false);
    assert(__traits(isAbstractClass, void*) == false);
    assert(__traits(isAbstractClass, void[]) == false);
    assert(__traits(isAbstractClass, void[3]) == false);
    assert(__traits(isAbstractClass, int[char]) == false);
    assert(__traits(isAbstractClass, float, float) == false);
    assert(__traits(isAbstractClass, float, S) == false);

    assert(__traits(isAbstractClass, void) == false);
    assert(__traits(isAbstractClass, byte) == false);
    assert(__traits(isAbstractClass, ubyte) == false);
    assert(__traits(isAbstractClass, short) == false);
    assert(__traits(isAbstractClass, ushort) == false);
    assert(__traits(isAbstractClass, int) == false);
    assert(__traits(isAbstractClass, uint) == false);
    assert(__traits(isAbstractClass, long) == false);
    assert(__traits(isAbstractClass, ulong) == false);
    assert(__traits(isAbstractClass, float) == false);
    assert(__traits(isAbstractClass, double) == false);
    assert(__traits(isAbstractClass, real) == false);
    assert(__traits(isAbstractClass, char) == false);
    assert(__traits(isAbstractClass, wchar) == false);
    assert(__traits(isAbstractClass, dchar) == false);

    assert(__traits(isAbstractClass, AC2) == true);
    assert(__traits(isAbstractClass, AC3) == true);
}

/********************************************************/

void test9()
{
    assert(__traits(isFinalClass) == false);
    assert(__traits(isFinalClass, C) == false);
    assert(__traits(isFinalClass, FC) == true);
}

/********************************************************/

void test11()
{
    assert(__traits(isAbstractFunction, C.bar) == false);
    assert(__traits(isAbstractFunction, S.bar) == false);
    assert(__traits(isAbstractFunction, AC2.foo) == true);
}

/********************************************************/

void test12()
{
    assert(__traits(isFinalFunction, C.bar) == false);
    assert(__traits(isFinalFunction, S.bar) == false);
    assert(__traits(isFinalFunction, AC2.foo) == false);
    assert(__traits(isFinalFunction, FC.foo) == true);
    assert(__traits(isFinalFunction, C.foo) == true);
}

/********************************************************/

void test13()
{
    S s;
    __traits(getMember, s, "x") = 7;
    auto i = __traits(getMember, s, "x");
    assert(i == 7);
    auto j = __traits(getMember, S, "z");
    assert(j == 5);

    assert(__traits(hasMember, s, "x") == true);
    assert(__traits(hasMember, S, "z") == true);
    assert(__traits(hasMember, S, "aaa") == false);

    auto k = __traits(classInstanceSize, C);
    assert(k == C.classinfo.initializer.length);
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=7123

private struct DelegateFaker7123(F)
{
    template GeneratingPolicy() {}
    enum WITH_BASE_CLASS = __traits(hasMember, GeneratingPolicy!(), "x");
}

auto toDelegate7123(F)(F fp)
{
    alias DelegateFaker7123!F Faker;
}


void test7123()
{
    static assert(is(typeof(toDelegate7123(&main))));
}

/********************************************************/

class D14
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 0; }
}

void test14()
{
    auto a = [__traits(derivedMembers, D14)];
    assert(a == ["__ctor","__dtor","foo", "__xdtor"]);
}

/********************************************************/

class D15
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

/********************************************************/

struct S16 { }

int foo16();
int bar16();

void test16()
{
    assert(__traits(isSame, foo16, foo16) == true);
    assert(__traits(isSame, foo16, bar16) == false);
    assert(__traits(isSame, foo16, S16) == false);
    assert(__traits(isSame, S16, S16) == true);
    assert(__traits(isSame, core, S16) == false);
    assert(__traits(isSame, core, core) == true);
}

/********************************************************/

struct S17
{
    static int s1;
    int s2;
}

int foo17();

void test17()
{
    assert(__traits(compiles) == false);
    assert(__traits(compiles, foo17) == true);
    assert(__traits(compiles, foo17 + 1) == true);
    assert(__traits(compiles, &foo17 + 1) == false);
    assert(__traits(compiles, typeof(1)) == true);
    assert(__traits(compiles, S17.s1) == true);
    assert(__traits(compiles, S17.s3) == false);
    assert(__traits(compiles, 1,2,3,int,long,core) == true);
    assert(__traits(compiles, 3[1]) == false);
    assert(__traits(compiles, 1,2,3,int,long,3[1]) == false);
}

/********************************************************/

interface D18
{
  extern(Windows):
    void foo();
    int foo(int);
}

void test18()
{
    auto a = __traits(allMembers, D18);
    assert(a.length == 1);
}


/********************************************************/

class C19
{
    void mutating_method(){}

    const void const_method(){}

    void bastard_method(){}
    const void bastard_method(int){}
}


void test19()
{
    auto a = __traits(allMembers, C19);
    assert(a.length == 9);

    foreach( m; __traits(allMembers, C19) )
        printf("%.*s\n", cast(int)m.length, m.ptr);
}


/********************************************************/

void test20()
{
    void fooref(ref int x)
    {
        static assert(__traits(isRef, x));
        static assert(!__traits(isOut, x));
        static assert(!__traits(isLazy, x));
    }

    void fooout(out int x)
    {
        static assert(!__traits(isRef, x));
        static assert(__traits(isOut, x));
        static assert(!__traits(isLazy, x));
    }

    void foolazy(lazy int x)
    {
        static assert(!__traits(isRef, x));
        static assert(!__traits(isOut, x));
        static assert(__traits(isLazy, x));
    }
}

/********************************************************/

void test21()
{
    assert(__traits(isStaticFunction, C.bar) == false);
    assert(__traits(isStaticFunction, C.abc) == true);
    assert(__traits(isStaticFunction, S.bar) == false);
}

/********************************************************/

class D22
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

void test22()
{
    D22 d = new D22();

    assert(typeid(typeof(__traits(getOverloads, D22, "foo")[0])).toString()
           == "void function()");
    assert(typeid(typeof(__traits(getOverloads, D22, "foo")[1])).toString()
           == "int function(int)");

    alias typeof(__traits(getOverloads, D22, "foo")) b;
    assert(typeid(b[0]).toString() == "void function()");
    assert(typeid(b[1]).toString() == "int function(int)");

    auto i = __traits(getOverloads, d, "foo")[1](1);
    assert(i == 2);
}

/********************************************************/

string toString23(E)(E value) if (is(E == enum)) {
   foreach (s; __traits(allMembers, E)) {
      if (value == mixin("E." ~ s)) return s;
   }
   return null;
}

enum OddWord { acini, alembicated, prolegomena, aprosexia }

void test23()
{
   auto w = OddWord.alembicated;
   assert(toString23(w) == "alembicated");
}

/********************************************************/

struct Test24
{
    public void test24(int){}
    private void test24(int, int){}
}

static assert(__traits(getVisibility, __traits(getOverloads, Test24, "test24")[1]) == "private");

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=1369

void test1369()
{
    class C1
    {
        static int count;
        void func() { count++; }
    }

    // variable symbol
    C1 c1 = new C1;
    __traits(getMember, c1, "func")();      // TypeIdentifier -> VarExp
    __traits(getMember, mixin("c1"), "func")(); // Expression -> VarExp
    assert(C1.count == 2);

    // nested function symbol
    @property C1 get() { return c1; }
    __traits(getMember, get, "func")();
    __traits(getMember, mixin("get"), "func")();
    assert(C1.count == 4);

    class C2
    {
        C1 c1;
        this() { c1 = new C1; }
        void test()
        {
            // variable symbol (this.outer.c1)
            __traits(getMember, c1, "func")();      // TypeIdentifier -> VarExp -> DotVarExp
            __traits(getMember, mixin("c1"), "func")(); // Expression -> VarExp -> DotVarExp
            assert(C1.count == 6);

            // nested function symbol (this.outer.get)
            __traits(getMember, get, "func")();
            __traits(getMember, mixin("get"), "func")();
            assert(C1.count == 8);
        }
    }
    C2 c2 = new C2;
    c2.test();
}

/********************************************************/

template Foo2234(){ int x; }

struct S2234a{ mixin Foo2234; }
struct S2234b{ mixin Foo2234; mixin Foo2234; }
struct S2234c{ alias Foo2234!() foo; }

static assert([__traits(allMembers, S2234a)] == ["x"]);
static assert([__traits(allMembers, S2234b)] == ["x"]);
static assert([__traits(allMembers, S2234c)] == ["foo"]);

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=5878

template J5878(A)
{
    static if (is(A P == super))
        alias P J5878;
}

alias J5878!(A5878) Z5878;

class X5878 {}
class A5878 : X5878 {}

/********************************************************/

mixin template Members6674()
{
    static int i1;
    static int i2;
    static int i3;  //comment out to make func2 visible
    static int i4;  //comment out to make func1 visible
}

class Test6674
{
    mixin Members6674;

    alias void function() func1;
    alias bool function() func2;
}

static assert([__traits(allMembers,Test6674)] == [
    "i1","i2","i3","i4",
    "func1","func2",
    "toString","toHash","opCmp","opEquals","Monitor","factory"]);

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=6073

struct S6073 {}

template T6073(M...) {
    //alias int T;
}
alias T6073!traits V6073;                       // ok
alias T6073!(__traits(parent, S6073)) U6073;    // error
static assert(__traits(isSame, V6073, U6073));  // same instantiation == same arguemnts

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=7027

struct Foo7027 { int a; }
static assert(!__traits(compiles, { return Foo7027.a; }));

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9213

class Foo9213 { int a; }
static assert(!__traits(compiles, { return Foo9213.a; }));

/********************************************************/

interface AA
{
     int YYY();
}

class DD
{
    final int YYY() { return 4; }
}

static assert(__traits(isVirtualMethod, DD.YYY) == false);
static assert(__traits(getVirtualMethods, DD, "YYY").length == 0);

class EE
{
     int YYY() { return 0; }
}

class FF : EE
{
    final override int YYY() { return 4; }
}

static assert(__traits(isVirtualMethod, FF.YYY));
static assert(__traits(getVirtualMethods, FF, "YYY").length == 1);

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=7608

struct S7608a(bool T)
{
    static if (T) { int x; }
    int y;
}
struct S7608b
{
    version(none) { int x; }
    int y;
}
template TypeTuple7608(T...){ alias T TypeTuple7608; }
void test7608()
{
    alias TypeTuple7608!(__traits(allMembers, S7608a!false)) MembersA;
    static assert(MembersA.length == 1);
    static assert(MembersA[0] == "y");

    alias TypeTuple7608!(__traits(allMembers, S7608b)) MembersB;
    static assert(MembersB.length == 1);
    static assert(MembersB[0] == "y");
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=7858

void test7858()
{
    class C
    {
        final void ffunc(){}
        final void ffunc(int){}

        void vfunc(){}
        void vfunc(int){}

        abstract void afunc();
        abstract void afunc(int);

        static void sfunc(){}
        static void sfunc(int){}
    }

    static assert(__traits(isFinalFunction, C.ffunc) ==
                  __traits(isFinalFunction, __traits(getOverloads, C, "ffunc")[0]));    // NG
    static assert(__traits(isVirtualMethod, C.vfunc) ==
                  __traits(isVirtualMethod, __traits(getOverloads, C, "vfunc")[0]));    // NG
    static assert(__traits(isAbstractFunction, C.afunc) ==
                  __traits(isAbstractFunction, __traits(getOverloads, C, "afunc")[0])); // OK
    static assert(__traits(isStaticFunction, C.sfunc) ==
                  __traits(isStaticFunction, __traits(getOverloads, C, "sfunc")[0]));   // OK

    static assert(__traits(isSame, C.ffunc, __traits(getOverloads, C, "ffunc")[0]));    // NG
    static assert(__traits(isSame, C.vfunc, __traits(getOverloads, C, "vfunc")[0]));    // NG
    static assert(__traits(isSame, C.afunc, __traits(getOverloads, C, "afunc")[0]));    // NG
    static assert(__traits(isSame, C.sfunc, __traits(getOverloads, C, "sfunc")[0]));    // NG
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=8971

template Tuple8971(TL...){ alias TL Tuple8971; }

class A8971
{
    void bar() {}

    void connect()
    {
        alias Tuple8971!(__traits(getOverloads, typeof(this), "bar")) overloads;
        static assert(__traits(isSame, overloads[0], bar));
    }
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=8972

struct A8972
{
    void foo() {}

    void connect()
    {
        alias Tuple8971!(__traits(getOverloads, typeof(this), "foo")) overloads;
        static assert(__traits(isSame, overloads[0], foo));
    }
}

/********************************************************/

private   struct TestProt1 {}
package   struct TestProt2 {}
protected struct TestProt3 {}
public    struct TestProt4 {}
export    struct TestProt5 {}

void getVisibility()
{
    class Test
    {
        private   { int va; void fa(){} }
        package   { int vb; void fb(){} }
        protected { int vc; void fc(){} }
        public    { int vd; void fd(){} }
        export    { int ve; void fe(){} }
    }
    Test t;

    // TOKvar and VarDeclaration
    static assert(__traits(getVisibility, Test.va) == "private");
    static assert(__traits(getVisibility, Test.vb) == "package");
    static assert(__traits(getVisibility, Test.vc) == "protected");
    static assert(__traits(getVisibility, Test.vd) == "public");
    static assert(__traits(getVisibility, Test.ve) == "export");

    // TOKdotvar and VarDeclaration
    static assert(__traits(getVisibility, t.va) == "private");
    static assert(__traits(getVisibility, t.vb) == "package");
    static assert(__traits(getVisibility, t.vc) == "protected");
    static assert(__traits(getVisibility, t.vd) == "public");
    static assert(__traits(getVisibility, t.ve) == "export");

    // TOKvar and FuncDeclaration
    static assert(__traits(getVisibility, Test.fa) == "private");
    static assert(__traits(getVisibility, Test.fb) == "package");
    static assert(__traits(getVisibility, Test.fc) == "protected");
    static assert(__traits(getVisibility, Test.fd) == "public");
    static assert(__traits(getVisibility, Test.fe) == "export");

    // TOKdotvar and FuncDeclaration
    static assert(__traits(getVisibility, t.fa) == "private");
    static assert(__traits(getVisibility, t.fb) == "package");
    static assert(__traits(getVisibility, t.fc) == "protected");
    static assert(__traits(getVisibility, t.fd) == "public");
    static assert(__traits(getVisibility, t.fe) == "export");

    // TOKtype
    static assert(__traits(getVisibility, TestProt1) == "private");
    static assert(__traits(getVisibility, TestProt2) == "package");
    static assert(__traits(getVisibility, TestProt3) == "protected");
    static assert(__traits(getVisibility, TestProt4) == "public");
    static assert(__traits(getVisibility, TestProt5) == "export");

    // This specific pattern is important to ensure it always works
    // through reflection, however that becomes implemented
    static assert(__traits(getVisibility, __traits(getMember, t, "va")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, t, "vb")) == "package");
    static assert(__traits(getVisibility, __traits(getMember, t, "vc")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, t, "vd")) == "public");
    static assert(__traits(getVisibility, __traits(getMember, t, "ve")) == "export");
    static assert(__traits(getVisibility, __traits(getMember, t, "fa")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, t, "fb")) == "package");
    static assert(__traits(getVisibility, __traits(getMember, t, "fc")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, t, "fd")) == "public");
    static assert(__traits(getVisibility, __traits(getMember, t, "fe")) == "export");
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9546

void test9546()
{
    import imports.a9546 : S;

    S s;
    static assert(__traits(getVisibility, s.privA) == "private");
    static assert(__traits(getVisibility, s.protA) == "protected");
    static assert(__traits(getVisibility, s.packA) == "package");
    static assert(__traits(getVisibility, S.privA) == "private");
    static assert(__traits(getVisibility, S.protA) == "protected");
    static assert(__traits(getVisibility, S.packA) == "package");

    static assert(__traits(getVisibility, mixin("s.privA")) == "private");
    static assert(__traits(getVisibility, mixin("s.protA")) == "protected");
    static assert(__traits(getVisibility, mixin("s.packA")) == "package");
    static assert(__traits(getVisibility, mixin("S.privA")) == "private");
    static assert(__traits(getVisibility, mixin("S.protA")) == "protected");
    static assert(__traits(getVisibility, mixin("S.packA")) == "package");

    static assert(__traits(getVisibility, __traits(getMember, s, "privA")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, s, "protA")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, s, "packA")) == "package");
    static assert(__traits(getVisibility, __traits(getMember, S, "privA")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, S, "protA")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, S, "packA")) == "package");

    static assert(__traits(getVisibility, s.privF) == "private");
    static assert(__traits(getVisibility, s.protF) == "protected");
    static assert(__traits(getVisibility, s.packF) == "package");
    static assert(__traits(getVisibility, S.privF) == "private");
    static assert(__traits(getVisibility, S.protF) == "protected");
    static assert(__traits(getVisibility, S.packF) == "package");

    static assert(__traits(getVisibility, mixin("s.privF")) == "private");
    static assert(__traits(getVisibility, mixin("s.protF")) == "protected");
    static assert(__traits(getVisibility, mixin("s.packF")) == "package");
    static assert(__traits(getVisibility, mixin("S.privF")) == "private");
    static assert(__traits(getVisibility, mixin("S.protF")) == "protected");
    static assert(__traits(getVisibility, mixin("S.packF")) == "package");

    static assert(__traits(getVisibility, __traits(getMember, s, "privF")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, s, "protF")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, s, "packF")) == "package");
    static assert(__traits(getVisibility, __traits(getMember, S, "privF")) == "private");
    static assert(__traits(getVisibility, __traits(getMember, S, "protF")) == "protected");
    static assert(__traits(getVisibility, __traits(getMember, S, "packF")) == "package");
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9091

template isVariable9091(X...) if (X.length == 1)
{
    enum isVariable9091 = true;
}
class C9091
{
    int x;  // some class members
    void func(int n){ this.x = n; }

    void test()
    {
        alias T = C9091;
        enum is_x = isVariable9091!(__traits(getMember, T, "x"));

        foreach (i, m; __traits(allMembers, T))
        {
            enum x = isVariable9091!(__traits(getMember, T, m));
            static if (i == 0)  // x
            {
                __traits(getMember, T, m) = 10;
                assert(this.x == 10);
            }
            static if (i == 1)  // func
            {
                __traits(getMember, T, m)(20);
                assert(this.x == 20);
            }
        }
    }
}
struct S9091
{
    int x;  // some struct members
    void func(int n){ this.x = n; }

    void test()
    {
        alias T = S9091;
        enum is_x = isVariable9091!(__traits(getMember, T, "x"));

        foreach (i, m; __traits(allMembers, T))
        {
            enum x = isVariable9091!(__traits(getMember, T, m));
            static if (i == 0)  // x
            {
                __traits(getMember, T, m) = 10;
                assert(this.x == 10);
            }
            static if (i == 1)  // func
            {
                __traits(getMember, T, m)(20);
                assert(this.x == 20);
            }
        }
    }
}

void test9091()
{
    auto c = new C9091();
    c.test();

    auto s = S9091();
    s.test();
}

/********************************************************/

struct CtorS_9237 { this(int x) { } }       // ctor -> POD
struct DtorS_9237 { ~this() { } }           // dtor -> nonPOD
struct PostblitS_9237 { this(this) { } }    // cpctor -> nonPOD

struct NonPOD1_9237
{
    DtorS_9237 field;  // nonPOD -> ng
}

struct NonPOD2_9237
{
    DtorS_9237[2] field;  // static array of nonPOD -> ng
}

struct POD1_9237
{
    DtorS_9237* field;  // pointer to nonPOD -> ok
}

struct POD2_9237
{
    DtorS_9237[] field;  // dynamic array of nonPOD -> ok
}

struct POD3_9237
{
    int x = 123;
}

class C_9273 { }

void test9237()
{
    int x;
    struct NS_9237  // acceses .outer -> nested
    {
        void foo() { x++; }
    }

    struct NonNS_9237 { }  // doesn't access .outer -> non-nested
    static struct StatNS_9237 { }  // can't access .outer -> non-nested

    static assert(!__traits(isPOD, NS_9237));
    static assert(__traits(isPOD, NonNS_9237));
    static assert(__traits(isPOD, StatNS_9237));
    static assert(__traits(isPOD, CtorS_9237));
    static assert(!__traits(isPOD, DtorS_9237));
    static assert(!__traits(isPOD, PostblitS_9237));
    static assert(!__traits(isPOD, NonPOD1_9237));
    static assert(!__traits(isPOD, NonPOD2_9237));
    static assert(__traits(isPOD, POD1_9237));
    static assert(__traits(isPOD, POD2_9237));
    static assert(__traits(isPOD, POD3_9237));

    // static array of POD/non-POD types
    static assert(!__traits(isPOD, NS_9237[2]));
    static assert(__traits(isPOD, NonNS_9237[2]));
    static assert(__traits(isPOD, StatNS_9237[2]));
    static assert(__traits(isPOD, CtorS_9237[2]));
    static assert(!__traits(isPOD, DtorS_9237[2]));
    static assert(!__traits(isPOD, PostblitS_9237[2]));
    static assert(!__traits(isPOD, NonPOD1_9237[2]));
    static assert(!__traits(isPOD, NonPOD2_9237[2]));
    static assert(__traits(isPOD, POD1_9237[2]));
    static assert(__traits(isPOD, POD2_9237[2]));
    static assert(__traits(isPOD, POD3_9237[2]));

    // non-structs are POD types
    static assert(__traits(isPOD, C_9273));
    static assert(__traits(isPOD, int));
    static assert(__traits(isPOD, int*));
    static assert(__traits(isPOD, int[]));
    static assert(!__traits(compiles, __traits(isPOD, 123) ));
}

/*************************************************************/
// https://issues.dlang.org/show_bug.cgi?id=5978

void test5978()
{
    () {
        int x;
        pragma(msg, __traits(identifier, __traits(parent, x)));
    } ();
}

/*************************************************************/

template T7408() { }

void test7408()
{
    auto x = T7408!().stringof;
    auto y = T7408!().mangleof;
    static assert(__traits(compiles, T7408!().stringof));
    static assert(__traits(compiles, T7408!().mangleof));
    static assert(!__traits(compiles, T7408!().init));
    static assert(!__traits(compiles, T7408!().offsetof));
}

/*************************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9552

class C9552
{
    int f() { return 10; }
    int f(int n) { return n * 2; }
}

void test9552()
{
    auto c = new C9552;
    auto dg1 = &(__traits(getOverloads, c, "f")[0]); // DMD crashes
    assert(dg1() == 10);
    auto dg2 = &(__traits(getOverloads, c, "f")[1]);
    assert(dg2(10) == 20);
}

/*************************************************************/

void test9136()
{
    int x;
    struct S1 { void f() { x++; } }
    struct U1 { void f() { x++; } }
    static struct S2 { }
    static struct S3 { S1 s; }
    static struct U2 { }
    void f1() { x++; }
    static void f2() { }

    static assert(__traits(isNested, S1));
    static assert(__traits(isNested, U1));
    static assert(!__traits(isNested, S2));
    static assert(!__traits(isNested, S3));
    static assert(!__traits(isNested, U2));
    static assert(!__traits(compiles, __traits(isNested, int) ));
    static assert(!__traits(compiles, __traits(isNested, f1, f2) ));
    static assert(__traits(isNested, f1));
    static assert(!__traits(isNested, f2));

    static class A { static class SC { } class NC { } }
    static assert(!__traits(isNested, A));
    static assert(!__traits(isNested, A.SC));
    static assert(__traits(isNested, A.NC));
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9939

struct Test9939
{
    int f;
    enum /*Anonymous enum*/
    {
        A,
        B
    }
    enum NamedEnum
    {
        C,
        D
    }
}

static assert([__traits(allMembers, Test9939)] == ["f", "A", "B", "NamedEnum"]);

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=10043

void test10043()
{
    struct X {}
    X d1;
    static assert(!__traits(compiles, d1.structuralCast!Refleshable));
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=10096

struct S10096X
{
    string str;

    invariant() {}
    invariant() {}
    unittest {}
    unittest {}

    this(int) {}
    this(this) {}
    ~this() {}

    string getStr() in(str) out(r; r == str) { return str; }
}
static assert(
    [__traits(allMembers, S10096X)] ==
    ["str", "__ctor", "__postblit", "__dtor", "getStr", "__xdtor", "__xpostblit", "opAssign"]);

class C10096X
{
    string str;

    invariant() {}
    invariant() {}
    unittest {}
    unittest {}

    this(int) {}
    ~this() {}

    string getStr() in(str) out(r; r == str) { return str; }
}
static assert(
    [__traits(allMembers, C10096X)] ==
    ["str", "__ctor", "__dtor", "getStr", "__xdtor", "toString", "toHash", "opCmp", "opEquals", "Monitor", "factory"]);

// --------

string foo10096(alias var, T = typeof(var))()
{
    foreach (idx, member; __traits(allMembers, T))
    {
        auto x = var.tupleof[idx];
    }

    return "";
}

string foo10096(T)(T var)
{
    return "";
}

struct S10096
{
    int i;
    string s;
}

void test10096()
{
    S10096 s = S10096(1, "");
    auto x = foo10096!s;
}

/********************************************************/

unittest { }

struct GetUnitTests
{
    unittest { }
}

void test_getUnitTests ()
{
    // Always returns empty tuple if the -unittest flag isn't used
    static assert(__traits(getUnitTests, mixin(__MODULE__)).length == 0);
    static assert(__traits(getUnitTests, GetUnitTests).length == 0);
}

/********************************************************/

class TestIsOverrideFunctionBase
{
    void bar () {}
}

class TestIsOverrideFunctionPass : TestIsOverrideFunctionBase
{
    override void bar () {}
}

void test_isOverrideFunction ()
{
    assert(__traits(isOverrideFunction, TestIsOverrideFunctionPass.bar) == true);
    assert(__traits(isOverrideFunction, TestIsOverrideFunctionBase.bar) == false);
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11711
// Add __traits(getAliasThis)

alias TypeTuple(T...) = T;

void test11711()
{
    struct S1
    {
        string var;
        alias var this;
    }
    static assert(__traits(getAliasThis, S1) == TypeTuple!("var"));
    static assert(is(typeof(__traits(getMember, S1.init, __traits(getAliasThis, S1)[0]))
                == string));

    struct S2
    {
        TypeTuple!(int, string) var;
        alias var this;
    }
    static assert(__traits(getAliasThis, S2) == TypeTuple!("var"));
    static assert(is(typeof(__traits(getMember, S2.init, __traits(getAliasThis, S2)[0]))
                == TypeTuple!(int, string)));

    // https://issues.dlang.org/show_bug.cgi?id=19439
    // Return empty tuple for non-aggregate types.
    static assert(__traits(getAliasThis, int).length == 0);
}


/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12278

class Foo12278
{
    InPlace12278!Bar12278 inside;
}

class Bar12278 { }

struct InPlace12278(T)
{
    static assert(__traits(classInstanceSize, T) != 0);
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12571

mixin template getScopeName12571()
{
    enum string scopeName = __traits(identifier, __traits(parent, scopeName));
}

void test12571()
{
    mixin getScopeName12571;
    static assert(scopeName == "test12571");
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12237

auto f12237(T)(T a)
{
    static if (is(typeof(a) == int))
        return f12237("");
    else
        return 10;
}

void test12237()
{
    assert(f12237(1) == 10);

    assert((a){
        static if (is(typeof(a) == int))
        {
            int x;
            return __traits(parent, x)("");
        }
        else
            return 10;
    }(1) == 10);
}

/********************************************************/

void async(ARGS...)(ARGS)
{
        static void compute(ARGS)
        {
        }

        auto x = __traits(getParameterStorageClasses, compute, 1);
}

alias test17495 = async!(int, int);

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=15094

void test15094()
{
    static struct Foo { int i; }
    static struct Bar { Foo foo; }

    Bar bar;
    auto n = __traits(getMember, bar.foo, "i");
    assert(n == bar.foo.i);
}

/********************************************************/

void testIsDisabled()
{
    static assert(__traits(isDisabled, D1.true_));
    static assert(!__traits(isDisabled, D1.false_));
    static assert(!__traits(isDisabled, D1));
}

/********************************************************/
// https://issues.dlang.org/show_bug.cgi?id=10100

enum E10100
{
    value,
    _value,
    __value,
    ___value,
    ____value,
}
static assert(
    [__traits(allMembers, E10100)] ==
    ["value", "_value", "__value", "___value", "____value"]);

/********************************************************/

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
    test11();
    test12();
    test13();
    test7123();
    test14();
    test16();
    test17();
    test18();
    test19();
    test20();
    test21();
    test22();
    test23();
    test1369();
    test7608();
    test7858();
    test9091();
    test5978();
    test7408();
    test9552();
    test9136();
    test10096();
    test_getUnitTests();
    test_isOverrideFunction();
    test12237();
    test15094();

    printf("Success\n");
    return 0;
}
