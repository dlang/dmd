
import std.stdio;

alias int myint;
struct S { void bar() { } int x = 4; static int z = 5; }
class C { void bar() { } final void foo() { } static void abc() { } }
abstract class AC { }
class AC2 { abstract void foo(); }
class AC3 : AC2 { }
final class FC { void foo() { } }
enum E { EMEM }

/********************************************************/

void test1()
{
    auto t = __traits(isArithmetic, int);
    writeln(t);
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
    assert(__traits(isArithmetic, ifloat) == true);
    assert(__traits(isArithmetic, idouble) == true);
    assert(__traits(isArithmetic, ireal) == true);
    assert(__traits(isArithmetic, cfloat) == true);
    assert(__traits(isArithmetic, cdouble) == true);
    assert(__traits(isArithmetic, creal) == true);
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
    writeln(t);
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
    assert(__traits(isScalar, ifloat) == true);
    assert(__traits(isScalar, idouble) == true);
    assert(__traits(isScalar, ireal) == true);
    assert(__traits(isScalar, cfloat) == true);
    assert(__traits(isScalar, cdouble) == true);
    assert(__traits(isScalar, creal) == true);
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
    assert(__traits(isIntegral, ifloat) == false);
    assert(__traits(isIntegral, idouble) == false);
    assert(__traits(isIntegral, ireal) == false);
    assert(__traits(isIntegral, cfloat) == false);
    assert(__traits(isIntegral, cdouble) == false);
    assert(__traits(isIntegral, creal) == false);
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
    assert(__traits(isFloating, ifloat) == true);
    assert(__traits(isFloating, idouble) == true);
    assert(__traits(isFloating, ireal) == true);
    assert(__traits(isFloating, cfloat) == true);
    assert(__traits(isFloating, cdouble) == true);
    assert(__traits(isFloating, creal) == true);
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
    assert(__traits(isUnsigned, ifloat) == false);
    assert(__traits(isUnsigned, idouble) == false);
    assert(__traits(isUnsigned, ireal) == false);
    assert(__traits(isUnsigned, cfloat) == false);
    assert(__traits(isUnsigned, cdouble) == false);
    assert(__traits(isUnsigned, creal) == false);
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
    assert(__traits(isAssociativeArray, ifloat) == false);
    assert(__traits(isAssociativeArray, idouble) == false);
    assert(__traits(isAssociativeArray, ireal) == false);
    assert(__traits(isAssociativeArray, cfloat) == false);
    assert(__traits(isAssociativeArray, cdouble) == false);
    assert(__traits(isAssociativeArray, creal) == false);
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
    assert(__traits(isStaticArray, ifloat) == false);
    assert(__traits(isStaticArray, idouble) == false);
    assert(__traits(isStaticArray, ireal) == false);
    assert(__traits(isStaticArray, cfloat) == false);
    assert(__traits(isStaticArray, cdouble) == false);
    assert(__traits(isStaticArray, creal) == false);
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
    assert(__traits(isAbstractClass, ifloat) == false);
    assert(__traits(isAbstractClass, idouble) == false);
    assert(__traits(isAbstractClass, ireal) == false);
    assert(__traits(isAbstractClass, cfloat) == false);
    assert(__traits(isAbstractClass, cdouble) == false);
    assert(__traits(isAbstractClass, creal) == false);
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

void test10()
{
    assert(__traits(isVirtualFunction, C.bar) == true);
    assert(__traits(isVirtualFunction, S.bar) == false);
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

    writeln(__traits(hasMember, s, "x"));
    assert(__traits(hasMember, s, "x") == true);
    assert(__traits(hasMember, S, "z") == true);
    assert(__traits(hasMember, S, "aaa") == false);

    auto k = __traits(classInstanceSize, C);
    writeln(k);
    assert(k == C.classinfo.init.length);
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
    writeln(a);
    assert(a == ["__ctor","__dtor","foo"]);
}

/********************************************************/

class D15
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

void test15()
{
    D15 d = new D15();

    foreach (t; __traits(getVirtualFunctions, D15, "foo"))
	writeln(typeid(typeof(t)));

    alias typeof(__traits(getVirtualFunctions, D15, "foo")) b;
    foreach (t; b)
	writeln(typeid(t));

    auto i = __traits(getVirtualFunctions, d, "foo")[1](1);
    assert(i == 2);
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
    assert(__traits(isSame, std, S16) == false);
    assert(__traits(isSame, std, std) == true);
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
    assert(__traits(compiles, 1,2,3,int,long,std) == true);
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
    writeln(a);
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
    writeln(a);
    assert(a.length == 9);

    foreach( m; __traits(allMembers, C19) )
	writeln(m);
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

    foreach (t; __traits(getOverloads, D22, "foo"))
	writeln(typeid(typeof(t)));

    alias typeof(__traits(getOverloads, D22, "foo")) b;
    foreach (t; b)
	writeln(typeid(t));

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

template Foo2234(){ int x; }

struct S2234a{ mixin Foo2234; }
struct S2234b{ mixin Foo2234; mixin Foo2234; }
struct S2234c{ alias Foo2234!() foo; }

static assert([__traits(allMembers, S2234a)] == ["x"]);
static assert([__traits(allMembers, S2234b)] == ["x"]);
static assert([__traits(allMembers, S2234c)] == ["foo"]);

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
// 6073

struct S6073 {}

template T6073(M...) {
    //alias int T;
}
alias T6073!traits V6073;                       // ok
alias T6073!(__traits(parent, S6073)) U6073;    // error
static assert(__traits(isSame, V6073, U6073));  // same instantiation == same arguemnts

/********************************************************/

struct Foo7027 {
  int a;
}
static assert(!__traits(compiles, { return Foo7027.a; }));

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
    test10();
    test11();
    test12();
    test13();
    test14();
    test15();
    test16();
    test17();
    test18();
    test19();
    test20();
    test21();
    test22();
    test23();

    writeln("Success");
    return 0;
}
