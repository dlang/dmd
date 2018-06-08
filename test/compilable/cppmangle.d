
// Test C++ name mangling.
// See Bugs 4059, 5148, 7024, 10058

import core.stdc.stdio;

extern (C++) int foob(int i, int j, int k);

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

version (linux)
{
    static assert(foo.mangleof == "_Z3fooiii");
    static assert(foob.mangleof == "_Z4foobiii");
    static assert(C.bar.mangleof == "_ZN1C3barEiii");
}
version (Win32)
{
    static assert(foo.mangleof == "?foo@@YAHHHH@Z");
    static assert(foob.mangleof == "?foob@@YAHHHH@Z");
    static assert(C.bar.mangleof == "?bar@C@@UAEHHHH@Z");
}
version (Win64)
{
    static assert(foo.mangleof == "?foo@@YAHHHH@Z");
    static assert(foob.mangleof == "?foob@@YAHHHH@Z");
    static assert(C.bar.mangleof == "?bar@C@@UEAAHHHH@Z");
}

/****************************************/

extern (C++)
interface D
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

version (linux)
{
    static assert (getD.mangleof == "_Z4getDv");
    static assert (D.bar.mangleof == "_ZN1D3barEiii");
}

/****************************************/

extern (C++) int callE(E);

extern (C++)
interface E
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

version (linux)
{
    static assert (callE.mangleof == "_Z5callEP1E");
    static assert (E.bar.mangleof == "_ZN1E3barEiii");
    static assert (F.bar.mangleof == "_ZN1F3barEiii");
}

/****************************************/

extern (C++) void foo4(char* p);

void test4()
{
    foo4(null);
}

version (linux)
{
    static assert(foo4.mangleof == "_Z4foo4Pc");
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

version (linux)
{
    static assert(bar5.getFoo.mangleof == "_ZN4bar56getFooEi");
    static assert (newBar.mangleof == "_Z6newBarv");
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
    assert(f.i == 42);
    printf("f.d = %g\n", f.d);
    assert(f.d == 2.5);
}

version (linux)
{
    static assert (foo6.mangleof == "_Z4foo6v");
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

version (linux)
{
    static assert(foo8.mangleof == "_Z4foo8PKc");
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

version (linux)
{
    static assert(foobar9.mangleof == "_Z7foobar9P5elem9S0_");
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

/**************************************/
// 10058

extern (C++)
{
    void test10058a(void*) { }
    void test10058b(void function(void*)) { }
    void test10058c(void* function(void*)) { }
    void test10058d(void function(void*), void*) { }
    void test10058e(void* function(void*), void*) { }
    void test10058f(void* function(void*), void* function(void*)) { }
    void test10058g(void function(void*), void*, void*) { }
    void test10058h(void* function(void*), void*, void*) { }
    void test10058i(void* function(void*), void* function(void*), void*) { }
    void test10058j(void* function(void*), void* function(void*), void* function(void*)) { }
    void test10058k(void* function(void*), void* function(const (void)*)) { }
    void test10058l(void* function(void*), void* function(const (void)*), const(void)* function(void*)) { }
}

version (linux)
{
    static assert(test10058a.mangleof == "_Z10test10058aPv");
    static assert(test10058b.mangleof == "_Z10test10058bPFvPvE");
    static assert(test10058c.mangleof == "_Z10test10058cPFPvS_E");
    static assert(test10058d.mangleof == "_Z10test10058dPFvPvES_");
    static assert(test10058e.mangleof == "_Z10test10058ePFPvS_ES_");
    static assert(test10058f.mangleof == "_Z10test10058fPFPvS_ES1_");
    static assert(test10058g.mangleof == "_Z10test10058gPFvPvES_S_");
    static assert(test10058h.mangleof == "_Z10test10058hPFPvS_ES_S_");
    static assert(test10058i.mangleof == "_Z10test10058iPFPvS_ES1_S_");
    static assert(test10058j.mangleof == "_Z10test10058jPFPvS_ES1_S1_");
    static assert(test10058k.mangleof == "_Z10test10058kPFPvS_EPFS_PKvE");
    static assert(test10058l.mangleof == "_Z10test10058lPFPvS_EPFS_PKvEPFS3_S_E");
}

/**************************************/
// 11696

class Expression;
struct Loc {}

extern(C++)
class CallExp
{
    static void test11696a(Loc, Expression, Expression);
    static void test11696b(Loc, Expression, Expression*);
    static void test11696c(Loc, Expression*, Expression);
    static void test11696d(Loc, Expression*, Expression*);
}

version (linux)
{
    static assert(CallExp.test11696a.mangleof == "_ZN7CallExp10test11696aE3LocP10ExpressionS2_");
    static assert(CallExp.test11696b.mangleof == "_ZN7CallExp10test11696bE3LocP10ExpressionPS2_");
    static assert(CallExp.test11696c.mangleof == "_ZN7CallExp10test11696cE3LocPP10ExpressionS2_");
    static assert(CallExp.test11696d.mangleof == "_ZN7CallExp10test11696dE3LocPP10ExpressionS3_");
}

/**************************************/
// 13337

extern(C++, N13337a.N13337b.N13337c)
{
  struct S13337{}
  void foo13337(S13337 s);
}

version (linux)
{
    static assert(foo13337.mangleof == "_ZN7N13337a7N13337b7N13337c8foo13337ENS1_6S13337E");
}

/**************************************/
// 15789

extern (C++) void test15789a(T...)(T args);

void test15789()
{
    test15789a(0);
}

/**************************************/
// 7030

extern(C++)
{
    struct T
    {
        void foo(int) const;
        void bar(int);
        static __gshared int boo;
    }
}

version (Posix)
{
    static assert(T.foo.mangleof == "_ZNK1T3fooEi");
    static assert(T.bar.mangleof == "_ZN1T3barEi");
    static assert(T.boo.mangleof == "_ZN1T3booE");
}

/****************************************/

// Special cases of Itanium mangling

extern (C++, std)
{
    struct pair(T1, T2)
    {
        void swap(ref pair other);
    }

    struct allocator(T)
    {
        uint fooa() const;
        uint foob();
    }

    struct basic_string(T1, T2, T3)
    {
        uint fooa();
    }

    struct basic_istream(T1, T2)
    {
        uint fooc();
    }

    struct basic_ostream(T1, T2)
    {
        uint food();
    }

    struct basic_iostream(T1, T2)
    {
        uint fooe();
    }

    struct char_traits(T)
    {
        uint foof();
    }

    struct test18957 {}
}

version (linux)
{
    // https://issues.dlang.org/show_bug.cgi?id=17947
    static assert(std.pair!(void*, void*).swap.mangleof == "_ZNSt4pairIPvS0_E4swapERS1_");

    static assert(std.allocator!int.fooa.mangleof == "_ZNKSaIiE4fooaEv");
    static assert(std.allocator!int.foob.mangleof == "_ZNSaIiE4foobEv");
    static assert(std.basic_string!(char,int,uint).fooa.mangleof == "_ZNSbIcijE4fooaEv");
    static assert(std.basic_string!(char, std.char_traits!char, std.allocator!char).fooa.mangleof == "_ZNSs4fooaEv");
    static assert(std.basic_istream!(char, std.char_traits!char).fooc.mangleof == "_ZNSi4foocEv");
    static assert(std.basic_ostream!(char, std.char_traits!char).food.mangleof == "_ZNSo4foodEv");
    static assert(std.basic_iostream!(char, std.char_traits!char).fooe.mangleof == "_ZNSd4fooeEv");
}

/**************************************/

alias T36 = int ********** ********** ********** **********;

extern (C++) void test36(T36, T36*) { }

version (linux)
{
    static assert(test36.mangleof == "_Z6test36PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPiPS12_");
}

/*****************************************/
// https://issues.dlang.org/show_bug.cgi?id=17772

extern(C++, SPACE)
int test37(T)(){ return 0;}

version (Posix) // all non-Windows machines
{
    static assert(test37!int.mangleof == "_ZN5SPACE6test37IiEEiv");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=15388

extern (C++) void test15388(typeof(null));

version (Posix)
{
    static assert(test15388.mangleof == "_Z9test15388Dn");
}
version (Windows)
{
    static assert(test15388.mangleof == "?test15388@@YAX$$T@Z");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=14086

extern (C++) class Test14086
{
    this();
    ~this();
}
extern (C++) class Test14086_2
{
    final ~this();
}
extern (C++) struct Test14086_S
{
    this(int);
    ~this();
}

version(Posix)
{
    static assert(Test14086.__ctor.mangleof == "_ZN9Test14086C1Ev");
    static assert(Test14086.__dtor.mangleof == "_ZN9Test14086D1Ev");
    static assert(Test14086_2.__dtor.mangleof == "_ZN11Test14086_2D1Ev");
    static assert(Test14086_S.__ctor.mangleof == "_ZN11Test14086_SC1Ei");
    static assert(Test14086_S.__dtor.mangleof == "_ZN11Test14086_SD1Ev");
}
version(Win32)
{
    static assert(Test14086.__ctor.mangleof == "??0Test14086@@QAE@XZ");
    static assert(Test14086.__dtor.mangleof == "??1Test14086@@UAE@XZ");
    static assert(Test14086_2.__dtor.mangleof == "??1Test14086_2@@QAE@XZ");
    static assert(Test14086_S.__ctor.mangleof == "??0Test14086_S@@QAE@H@Z");
    static assert(Test14086_S.__dtor.mangleof == "??1Test14086_S@@QAE@XZ");
}
version(Win64)
{
    static assert(Test14086.__ctor.mangleof == "??0Test14086@@QEAA@XZ");
    static assert(Test14086.__dtor.mangleof == "??1Test14086@@UEAA@XZ");
    static assert(Test14086_2.__dtor.mangleof == "??1Test14086_2@@QEAA@XZ");
    static assert(Test14086_S.__ctor.mangleof == "??0Test14086_S@@QEAA@H@Z");
    static assert(Test14086_S.__dtor.mangleof == "??1Test14086_S@@QEAA@XZ");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=18888

extern (C++)
struct T18888(T)
{
    void fun();
}

extern (C++)
struct S18888(alias arg = T18888)
{
    alias I = T18888!(arg!int);
}

version(Posix)
{
    static assert(S18888!().I.fun.mangleof == "_ZN6T18888IS_IiEE3funEv");
}
version(Win32)
{
    static assert(S18888!().I.fun.mangleof == "?fun@?$T18888@U?$T18888@H@@@@QAEXXZ");
}
version(Win64)
{
    static assert(S18888!().I.fun.mangleof == "?fun@?$T18888@U?$T18888@H@@@@QEAAXXZ");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=18890

extern (C++) class C18890
{
    ~this() {}
}
extern (C++) class C18890_2
{
    ~this() {}
    extern (C++) struct Agg
    {
        ~this() {}
    }
    Agg s;
}

version (Posix)
{
    static assert(C18890.__dtor.mangleof == "_ZN6C18890D1Ev");
    static assert(C18890.__xdtor.mangleof == "_ZN6C18890D1Ev");
    static assert(C18890_2.__dtor.mangleof == "_ZN8C18890_26__dtorEv");
    static assert(C18890_2.__xdtor.mangleof == "_ZN8C18890_2D1Ev");
}
version (Win32)
{
    static assert(C18890.__dtor.mangleof == "??1C18890@@UAE@XZ");
    static assert(C18890.__xdtor.mangleof == "??1C18890@@UAE@XZ");
    static assert(C18890_2.__dtor.mangleof == "?__dtor@C18890_2@@UAE@XZ");
    static assert(C18890_2.__xdtor.mangleof == "??1C18890_2@@UAE@XZ");
}
version (Win64)
{
    static assert(C18890.__dtor.mangleof == "??1C18890@@UEAA@XZ");
    static assert(C18890.__xdtor.mangleof == "??1C18890@@UEAA@XZ");
    static assert(C18890_2.__dtor.mangleof == "?__dtor@C18890_2@@UEAA@XZ");
    static assert(C18890_2.__xdtor.mangleof == "??1C18890_2@@UEAA@XZ");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=18891

extern (C++) class C18891
{
    ~this();
    extern (C++) struct Agg
    {
        ~this() {}
    }
    Agg s;
}

version (Posix)
{
    static assert(C18891.__dtor.mangleof == "_ZN6C18891D1Ev");
    static assert(C18891.__xdtor.mangleof == "_ZN6C18891D1Ev");
}
version (Win32)
{
    static assert(C18891.__dtor.mangleof == "??1C18891@@UAE@XZ");
    static assert(C18891.__xdtor.mangleof == "??1C18891@@UAE@XZ");
}
version (Win64)
{
    static assert(C18891.__dtor.mangleof == "??1C18891@@UEAA@XZ");
    static assert(C18891.__xdtor.mangleof == "??1C18891@@UEAA@XZ");
}

/**************************************/
// Test C++ operator mangling

extern (C++) struct TestOperators
{
    int opCast(T)();
    int opBinary(string op)(int x);
    int opUnary(string op)();
    int opOpAssign(string op)(int x);
    int opIndex(int x);
    bool opEquals(int x);
    int opCall(int, float);
    int opAssign(int);
}

version (Posix)
{
    static assert(TestOperators.opUnary!"*".mangleof     == "_ZN13TestOperatorsdeEv");
    static assert(TestOperators.opUnary!"++".mangleof    == "_ZN13TestOperatorsppEv");
    static assert(TestOperators.opUnary!"--".mangleof    == "_ZN13TestOperatorsmmEv");
    static assert(TestOperators.opUnary!"-".mangleof     == "_ZN13TestOperatorsngEv");
    static assert(TestOperators.opUnary!"+".mangleof     == "_ZN13TestOperatorspsEv");
    static assert(TestOperators.opUnary!"~".mangleof     == "_ZN13TestOperatorscoEv");
    static assert(TestOperators.opBinary!">>".mangleof   == "_ZN13TestOperatorsrsEi");
    static assert(TestOperators.opBinary!"<<".mangleof   == "_ZN13TestOperatorslsEi");
    static assert(TestOperators.opBinary!"*".mangleof    == "_ZN13TestOperatorsmlEi");
    static assert(TestOperators.opBinary!"-".mangleof    == "_ZN13TestOperatorsmiEi");
    static assert(TestOperators.opBinary!"+".mangleof    == "_ZN13TestOperatorsplEi");
    static assert(TestOperators.opBinary!"&".mangleof    == "_ZN13TestOperatorsanEi");
    static assert(TestOperators.opBinary!"/".mangleof    == "_ZN13TestOperatorsdvEi");
    static assert(TestOperators.opBinary!"%".mangleof    == "_ZN13TestOperatorsrmEi");
    static assert(TestOperators.opBinary!"^".mangleof    == "_ZN13TestOperatorseoEi");
    static assert(TestOperators.opBinary!"|".mangleof    == "_ZN13TestOperatorsorEi");
    static assert(TestOperators.opOpAssign!"*".mangleof  == "_ZN13TestOperatorsmLEi");
    static assert(TestOperators.opOpAssign!"+".mangleof  == "_ZN13TestOperatorspLEi");
    static assert(TestOperators.opOpAssign!"-".mangleof  == "_ZN13TestOperatorsmIEi");
    static assert(TestOperators.opOpAssign!"/".mangleof  == "_ZN13TestOperatorsdVEi");
    static assert(TestOperators.opOpAssign!"%".mangleof  == "_ZN13TestOperatorsrMEi");
    static assert(TestOperators.opOpAssign!">>".mangleof == "_ZN13TestOperatorsrSEi");
    static assert(TestOperators.opOpAssign!"<<".mangleof == "_ZN13TestOperatorslSEi");
    static assert(TestOperators.opOpAssign!"&".mangleof  == "_ZN13TestOperatorsaNEi");
    static assert(TestOperators.opOpAssign!"|".mangleof  == "_ZN13TestOperatorsoREi");
    static assert(TestOperators.opOpAssign!"^".mangleof  == "_ZN13TestOperatorseOEi");
    static assert(TestOperators.opCast!int.mangleof      == "_ZN13TestOperatorscviEv");
    static assert(TestOperators.opAssign.mangleof        == "_ZN13TestOperatorsaSEi");
    static assert(TestOperators.opEquals.mangleof        == "_ZN13TestOperatorseqEi");
    static assert(TestOperators.opIndex.mangleof         == "_ZN13TestOperatorsixEi");
    static assert(TestOperators.opCall.mangleof          == "_ZN13TestOperatorsclEif");
}
version (Win32)
{
    static assert(TestOperators.opUnary!"*".mangleof     == "??DTestOperators@@QAEHXZ");
    static assert(TestOperators.opUnary!"++".mangleof    == "??ETestOperators@@QAEHXZ");
    static assert(TestOperators.opUnary!"--".mangleof    == "??FTestOperators@@QAEHXZ");
    static assert(TestOperators.opUnary!"-".mangleof     == "??GTestOperators@@QAEHXZ");
    static assert(TestOperators.opUnary!"+".mangleof     == "??HTestOperators@@QAEHXZ");
    static assert(TestOperators.opUnary!"~".mangleof     == "??STestOperators@@QAEHXZ");
    static assert(TestOperators.opBinary!">>".mangleof   == "??5TestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"<<".mangleof   == "??6TestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"*".mangleof    == "??DTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"-".mangleof    == "??GTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"+".mangleof    == "??HTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"&".mangleof    == "??ITestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"/".mangleof    == "??KTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"%".mangleof    == "??LTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"^".mangleof    == "??TTestOperators@@QAEHH@Z");
    static assert(TestOperators.opBinary!"|".mangleof    == "??UTestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"*".mangleof  == "??XTestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"+".mangleof  == "??YTestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"-".mangleof  == "??ZTestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"/".mangleof  == "??_0TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"%".mangleof  == "??_1TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!">>".mangleof == "??_2TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"<<".mangleof == "??_3TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"&".mangleof  == "??_4TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"|".mangleof  == "??_5TestOperators@@QAEHH@Z");
    static assert(TestOperators.opOpAssign!"^".mangleof  == "??_6TestOperators@@QAEHH@Z");
    static assert(TestOperators.opCast!int.mangleof      == "??BTestOperators@@QAEHXZ");
    static assert(TestOperators.opAssign.mangleof        == "??4TestOperators@@QAEHH@Z");
    static assert(TestOperators.opEquals.mangleof        == "??8TestOperators@@QAE_NH@Z");
    static assert(TestOperators.opIndex.mangleof         == "??ATestOperators@@QAEHH@Z");
    static assert(TestOperators.opCall.mangleof          == "??RTestOperators@@QAEHHM@Z");
}
version (Win64)
{
    static assert(TestOperators.opUnary!"*".mangleof     == "??DTestOperators@@QEAAHXZ");
    static assert(TestOperators.opUnary!"++".mangleof    == "??ETestOperators@@QEAAHXZ");
    static assert(TestOperators.opUnary!"--".mangleof    == "??FTestOperators@@QEAAHXZ");
    static assert(TestOperators.opUnary!"-".mangleof     == "??GTestOperators@@QEAAHXZ");
    static assert(TestOperators.opUnary!"+".mangleof     == "??HTestOperators@@QEAAHXZ");
    static assert(TestOperators.opUnary!"~".mangleof     == "??STestOperators@@QEAAHXZ");
    static assert(TestOperators.opBinary!">>".mangleof   == "??5TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"<<".mangleof   == "??6TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"*".mangleof    == "??DTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"-".mangleof    == "??GTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"+".mangleof    == "??HTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"&".mangleof    == "??ITestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"/".mangleof    == "??KTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"%".mangleof    == "??LTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"^".mangleof    == "??TTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opBinary!"|".mangleof    == "??UTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"*".mangleof  == "??XTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"+".mangleof  == "??YTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"-".mangleof  == "??ZTestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"/".mangleof  == "??_0TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"%".mangleof  == "??_1TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!">>".mangleof == "??_2TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"<<".mangleof == "??_3TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"&".mangleof  == "??_4TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"|".mangleof  == "??_5TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opOpAssign!"^".mangleof  == "??_6TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opCast!int.mangleof      == "??BTestOperators@@QEAAHXZ");
    static assert(TestOperators.opAssign.mangleof        == "??4TestOperators@@QEAAHH@Z");
    static assert(TestOperators.opEquals.mangleof        == "??8TestOperators@@QEAA_NH@Z");
    static assert(TestOperators.opIndex.mangleof         == "??ATestOperators@@QEAAHH@Z");
    static assert(TestOperators.opCall.mangleof          == "??RTestOperators@@QEAAHHM@Z");
}

extern(C++, Namespace18922)
{
    import cppmangle2;
    void func18922(Struct18922) {}

    version (Posix)
        static assert(func18922.mangleof == "_ZN14Namespace189229func18922ENS_11Struct18922E");
    else version(Windows)
        static assert(func18922.mangleof == "?func18922@Namespace18922@@YAXUStruct18922@1@@Z");
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=18957
// extern(C++) doesn't mangle 'std' correctly on posix systems

version (Posix)
{
    extern (C++) void test18957(ref const(std.test18957) t) {}

    static assert(test18957.mangleof == "_Z9test18957RKNSt9test18957E");
}
