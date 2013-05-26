
extern(C) int printf(const char* fmt, ...);

template TypeTuple(T...){ alias T TypeTuple; }
template Id(      T){ alias T Id; }
template Id(alias A){ alias A Id; }

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

int main()
{
    test1680();
    test7418();
    test7552();
    test8668();
    test8943();
    test9410();
    test10171();

    printf("Success\n");
    return 0;
}
