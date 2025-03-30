/*
EXTRA_FILES: imports/a9741.d
TEST_OUTPUT:
---
AliasSeq!(3, 4, 7, (SSS))
AliasSeq!(3, 4, 7, (SSS))
7
SSS
AliasSeq!("hello")
AliasSeq!('c')
AliasSeq!((FFF))
AliasSeq!(10)
AliasSeq!(20)
AliasSeq!(30)
AliasSeq!((Test6))
AliasSeq!(Test7(3, "foo"))
AliasSeq!((Test8!"foo"))
AliasSeq!((Test9!"foo"))
AliasSeq!(Test10(3))
AliasSeq!(Test11(3))
AliasSeq!(10)
AliasSeq!(20)
AliasSeq!()
AliasSeq!(40)
B9741
AliasSeq!((A9741))
AliasSeq!(1)
AliasSeq!(2)
---

RUN_OUTPUT:
---
Success
---
*/

import core.stdc.stdio;

template Tuple(T...)
{
     alias T Tuple;
}



enum EEE = 7;
@("hello") struct SSS { }

@(3) { @(4)@(EEE)@(SSS) int foo; }

pragma(msg, __traits(getAttributes, foo));

alias Tuple!(__traits(getAttributes, foo)) TP;

pragma(msg, TP);
pragma(msg, TP[2]);
TP[3] a;
pragma(msg, typeof(a));


alias Tuple!(__traits(getAttributes, typeof(a))) TT;

pragma(msg, TT);

@('c') string s;
pragma(msg, __traits(getAttributes, s));

/************************************************/

enum FFF;
@(FFF) int x1;
pragma(msg, __traits(getAttributes, x1));

void test1()
{
    alias Tuple!(__traits(getAttributes, x1)) tp;
    assert(tp.length == 1);
    if (!is(FFF == tp[0]))
        assert(0);
}

/************************************************/

void test2()
{
    int x;
    alias Tuple!(__traits(getAttributes, x)) tp;
    assert(tp.length == 0);
}

/************************************************/

void test3()
{
    alias Tuple!(__traits(getAttributes, foo)) tp;
    assert(tp.length == 4);
    assert(tp[0] == 3);
    assert(tp[1] == 4);
    assert(tp[2] == 7);
}

/************************************************/

@(1) void foo4();
@(2) void foo4(int x);

void test4()
{
    int i = 1;
    foreach (o; __traits(getOverloads, uda, "foo4"))
    {
        alias Tuple!(__traits(getAttributes, o)) attrs;
        pragma(msg, attrs.stringof);
        assert(attrs[0] == i);
        ++i;
    }
}

/************************************************/

pragma(msg, __traits(getAttributes, aa));
alias Tuple!(__traits(getAttributes, aa)) Taa;
@(10) int aa;

pragma(msg, __traits(getAttributes, bb));
alias Tuple!(__traits(getAttributes, bb)) Tbb;
@(20) int bb;
alias Tuple!(__traits(getAttributes, bb)) Tbbc;

@(30) int cc;
pragma(msg, __traits(getAttributes, cc));
alias Tuple!(__traits(getAttributes, cc)) Tcc;

void test5()
{
    assert(Taa[0] == 10);
    assert(Tbb[0] == 20);
    assert(Tbbc[0] == 20);
    assert(Tcc[0] == 30);
}

/************************************************/

enum Test6;
@Test6 int x6;
pragma(msg, __traits(getAttributes, x6));

void test6()
{
    alias Tuple!(__traits(getAttributes, x6)) tp;

    assert(tp.length == 1);

    if (!is(Test6 == tp[0]))
        assert(0);
}

/************************************************/

struct Test7
{
    int a;
    string b;
}

@Test7(3, "foo") int x7;
pragma(msg, __traits(getAttributes, x7));

void test7()
{
    alias Tuple!(__traits(getAttributes, x7)) tp;

    assert(tp.length == 1);

    if (!is(Test7 == typeof(tp[0])))
        assert(0);

    assert(tp[0] == Test7(3, "foo"));
}

/************************************************/

struct Test8 (string foo) {}

@Test8!"foo" int x8;
pragma(msg, __traits(getAttributes, x8));

void test8()
{
    alias Tuple!(__traits(getAttributes, x8)) tp;

    assert(tp.length == 1);

    if (!is(Test8!("foo") == tp[0]))
        assert(0);
}

/************************************************/

struct Test9 (string foo) {}

@Test9!("foo") int x9;
pragma(msg, __traits(getAttributes, x9));

void test9()
{
    alias Tuple!(__traits(getAttributes, x9)) tp;

    assert(tp.length == 1);

    if (!is(Test9!("foo") == tp[0]))
        assert(0);
}

/************************************************/

struct Test10 (string foo)
{
    int a;
}

@Test10!"foo"(3) int x10;
pragma(msg, __traits(getAttributes, x10));

void test10()
{
    alias Tuple!(__traits(getAttributes, x10)) tp;

    assert(tp.length == 1);

    if (!is(Test10!("foo") == typeof(tp[0])))
        assert(0);

    assert(tp[0] == Test10!("foo")(3));
}

/************************************************/

struct Test11 (string foo)
{
    int a;
}

@Test11!("foo")(3) int x11;
pragma(msg, __traits(getAttributes, x11));

void test11()
{
    alias Tuple!(__traits(getAttributes, x11)) tp;

    assert(tp.length == 1);

    if (!is(Test11!("foo") == typeof(tp[0])))
        assert(0);

    assert(tp[0] == Test11!("foo")(3));
}

/************************************************/

void test12()
{
    @(1) static struct S1 { }
    S1 s1;
    static @(2) struct S2 { }
    S2 s2;
    @(1) @(2) struct S3 { }

    @(1) static @(2) struct S { }
    alias Tuple!(__traits(getAttributes, S)) tps;
    assert(tps.length == 2);
    assert(tps[0] == 1);
    assert(tps[1] == 2);

    @(3) int x;
    alias Tuple!(__traits(getAttributes, x)) tpx;
    assert(tpx.length == 1);
    assert(tpx[0] == 3);
    x = x + 1;

    @(4) int bar() { return x; }
    alias Tuple!(__traits(getAttributes, bar)) tpb;
    assert(tpb.length == 1);
    assert(tpb[0] == 4);
    bar();
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9178

void test9178()
{
    static class Foo { @(1) int a; }

    Foo foo = new Foo;
    static assert(__traits(getAttributes, foo.tupleof[0])[0] == 1);
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9652

struct Bug9652
{
    pragma(msg, __traits(getAttributes, enum_field));
    alias Tuple!(__traits(getAttributes, enum_field)) Tenum_field;
    private @(10) enum enum_field = 42;

    static assert(Tenum_field[0] == 10);
    static assert(__traits(getAttributes, enum_field)[0] == 10);
    static assert(__traits(getProtection, enum_field) == "private");
    static assert(__traits(isSame, __traits(parent, enum_field), Bug9652));
    static assert(__traits(isSame, enum_field, enum_field));

    pragma(msg, __traits(getAttributes, anon_enum_member));
    alias Tuple!(__traits(getAttributes, anon_enum_member)) Tanon_enum_member;
    private @(20) enum {anon_enum_member}

    static assert(Tanon_enum_member[0] == 20);
    static assert(__traits(getAttributes, anon_enum_member)[0] == 20);
    static assert(__traits(getProtection, anon_enum_member) == "private");
    static assert(__traits(isSame, __traits(parent, anon_enum_member), Bug9652));
    static assert(__traits(isSame, anon_enum_member, anon_enum_member));

    pragma(msg, __traits(getAttributes, Foo.enum_member));
    alias Tuple!(__traits(getAttributes, Foo.enum_member)) Tfoo_enum_member;
    private @(30) enum Foo {enum_member}
    static assert(Tfoo_enum_member.length == 0); //Foo has attributes, not Foo.enum_member
    static assert(__traits(getAttributes, Foo.enum_member).length == 0);
    static assert(__traits(getProtection, Foo.enum_member) == "public");
    static assert(__traits(isSame, __traits(parent, Foo.enum_member), Foo));
    static assert(__traits(isSame, Foo.enum_member, Foo.enum_member));

    pragma(msg, __traits(getAttributes, anon_enum_member_2));
    alias Tuple!(__traits(getAttributes, anon_enum_member_2)) Tanon_enum_member_2;
    private @(40) enum {long anon_enum_member_2 = 2L}

    static assert(Tanon_enum_member_2[0] == 40);
    static assert(__traits(getAttributes, anon_enum_member_2)[0] == 40);
    static assert(__traits(getProtection, anon_enum_member_2) == "private");
    static assert(__traits(isSame, __traits(parent, anon_enum_member_2), Bug9652));
    static assert(__traits(isSame, anon_enum_member_2, anon_enum_member_2));

    template Bug(alias X, bool is_exp)
    {
        static assert(is_exp == !__traits(compiles, __traits(parent, X)));
        static assert(is_exp == !__traits(compiles, __traits(getAttributes, X)));
        static assert(is_exp == !__traits(compiles, __traits(getProtection, X)));
        enum Bug = 0;
    }
    enum en = 0;
    enum dummy1 = Bug!(5, true);
    enum dummy2 = Bug!(en, false);
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=9741

import imports.a9741;

struct A9741 {}

alias X9741 = ShowAttributes!(B9741);

@A9741 struct B9741 {}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12160

auto before12160(alias Hook)(string) { return 0; }

template checkUDAs12160(alias Func)
{
    enum x = __traits(getAttributes, Func).length;
}

void test12160()
{
    int foo() { return 42; }    // OK <- NG

    @before12160!foo("name1")
    void bar(int name1, double name2) {}

    alias X = checkUDAs12160!(bar);
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=10208

@( 10)                enum int x10208_01 =  100;
@( 20)                     int x10208_02;
@( 30)               const int x10208_03;
@( 40)           immutable int x10208_04;
@( 50)                     int x10208_05 =  500;
@( 60)               const int x10208_06 =  600;
@( 70)           immutable int x10208_07 =  700;
@( 80) __gshared      enum int x10208_08 =  800;
@( 90) __gshared           int x10208_09;
@(100) __gshared     const int x10208_10;
@(110) __gshared immutable int x10208_11;
@(120) __gshared           int x10208_12 = 1200;
@(130) __gshared     const int x10208_13 = 1300;
@(140) __gshared immutable int x10208_14 = 1400;
static assert(__traits(getAttributes, x10208_01)[0] ==  10); // OK
static assert(__traits(getAttributes, x10208_02)[0] ==  20); // OK
static assert(__traits(getAttributes, x10208_03)[0] ==  30); // OK
static assert(__traits(getAttributes, x10208_04)[0] ==  40); // OK
static assert(__traits(getAttributes, x10208_05)[0] ==  50); // OK
static assert(__traits(getAttributes, x10208_06)[0] ==  60); // Error -> OK
static assert(__traits(getAttributes, x10208_07)[0] ==  70); // Error -> OK
static assert(__traits(getAttributes, x10208_08)[0] ==  80); // OK
static assert(__traits(getAttributes, x10208_09)[0] ==  90); // OK
static assert(__traits(getAttributes, x10208_10)[0] == 100); // OK
static assert(__traits(getAttributes, x10208_11)[0] == 110); // OK
static assert(__traits(getAttributes, x10208_12)[0] == 120); // OK
static assert(__traits(getAttributes, x10208_13)[0] == 130); // Error -> OK
static assert(__traits(getAttributes, x10208_14)[0] == 140); // Error -> OK

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11677
// https://issues.dlang.org/show_bug.cgi?id=11678

bool test_uda(alias func)() @safe
{
    alias Tuple!(__traits(getAttributes, func)) udas;
    static assert([udas] == [10, 20]);

    func(); // @safe attribute check

    return true;
}

@(10) @(20) @safe void func11677a() {}  // OK
@safe @(10) @(20) void func11677b() {}  // OK <- NG
@(10) @safe @(20) void func11677c() {}  // OK <- NG

static assert(test_uda!func11677a());
static assert(test_uda!func11677b());
static assert(test_uda!func11677c());

void func11678a() @safe @(10) @(20) {}  // OK <- NG
void func11678b() @(10) @safe @(20) {}  // OK <- NG
void func11678c() @(10) @(20) @safe {}  // OK <- NG

static assert(test_uda!func11678a());
static assert(test_uda!func11678b());
static assert(test_uda!func11678c());

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11678

class C11678
{
    this() @(10) @(20) {}
    ~this() @(10) @(20) {}
}

//static this() @(10) @(20) {}
static ~this() @(10) @(20) {}

//shared static this() @(10) @(20) {}
shared static ~this() @(10) @(20) {}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11679

void test11679()
{
    @(10) @(20) auto var = 1;
    static assert([__traits(getAttributes, var)] == [10, 20]);
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11680

@(10) gvar11680 = 1;  // OK <- NG
@(10) gfun11680() {}  // OK <- NG

void test11680()
{
    @(10) lvar11680 = 1;  // OK <- NG
    @(10) lfun11680() {}  // OK <- NG
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=11844

auto make_encode11844(T, string name)()
{
    return mixin("function(T self) { return self.encodeField!\""~ name ~ "\"();}");
}

class FileData11844
{
    ulong _member;

    @make_encode11844!(FileData11844, "member")()
    ulong member() const { return _member; }

    ubyte[] encodeField(string key)() { return [1,2,3]; }
}

static assert(__traits(getAttributes, FileData11844.member)[0](new FileData11844()) == [1,2,3]);

/************************************************/

template AliasSeq(T...)
{
    alias AliasSeq = T;
}

template ParameterUDA(size_t p_num, func...)
if (func.length == 1 && is(typeof(func[0]) PT == __parameters) && PT.length > p_num)
{
    static if (is(typeof(func[0]) PT == __parameters))
    {
        template Get(size_t i)
        {
            static if (//!isFunctionPointer!func && !isDelegate!func
                       // Parameters without UDA may yield CT error.
                       /*&&*/ is(typeof(__traits(getAttributes, PT[i..i+1]))x))
            {
                alias Get = AliasSeq!(__traits(getAttributes, PT[i..i+1]));
            }
            else
            {
                alias Get = AliasSeq!();
            }
        }
    }
    else
    {
        static assert(0, func[0].stringof ~ "is not a function");

        // Define dummy entities to avoid pointless errors
        template Get(size_t i) { alias Get = AliasSeq!(); }
        alias PT = AliasSeq!();
    }

    alias ParameterUDA = Get!p_num;
}

void test13x(@(10) int a, @(20) int, @(30) @(40) int[] arr...) {}

void test13()
{
    static assert([ParameterUDA!(0, test13x)] == [10]);
    static assert([ParameterUDA!(1, test13x)] == [20]);
    static assert([ParameterUDA!(2, test13x)] == [30, 40]);
}

template Test13t(F)
{
    static assert(!__traits(compiles, ParameterUDA!(0, F)));
    static assert(!__traits(compiles, ParameterUDA!(1, F)));
    static assert(!__traits(compiles, ParameterUDA!(2, F)));
    enum Test13t = true;
}

alias test13t = Test13t!(typeof(test13x));

enum Test14UDA1;

struct Test14UDA2
{
    string str;
}

Test14UDA2 test14uda3(string name)
{
    return Test14UDA2(name);
}

struct Test14UDA4(string v)
{
}

void test14x(@Test14UDA1 int, @Test14UDA2("1") int, @test14uda3("2") int, @Test14UDA4!"3" int) {}
void test14()
{
    static assert(is(ParameterUDA!(0, test14x)[0] == Test14UDA1));
    static assert(ParameterUDA!(1, test14x)[0] == Test14UDA2("1"));
    static assert(ParameterUDA!(2, test14x)[0] == test14uda3("2"));
    static assert(is(ParameterUDA!(3, test14x)[0] == Test14UDA4!"3"));
}

void test15x(@(20) void delegate(int) @safe dg)
{
    static assert([__traits(getAttributes, dg)] == [20]);
    static assert(is(typeof(dg) == void delegate(int) @safe));
}

template MinimalFunctionTypeOf(func...)
if (func.length == 1)
{
    static if (is(func[0] T) || is(typeof(func[0]) T) && is(T Fdlg == delegate))
        alias MinimalFunctionTypeOf = Fdlg; // HIT: delegate
    else
        static assert(0);
}

template Parameters(func...)
if (func.length == 1)
{
    static if (is(MinimalFunctionTypeOf!func P == function))
        alias Parameters = P;
    else
        static assert(0, "argument has no parameters");
}

void test15y(@(20) void delegate(@Test14UDA2("2") @("test15yUDA") int) @safe dg)
{
    static assert([__traits(getAttributes, dg)] == [20]);
    static assert(is(typeof(dg) == void delegate(int) @safe));
    auto foo = (@("myUDA") int x){
        static assert([__traits(getAttributes, x)] == ["myUDA"]);
    };
    static assert(__traits(getAttributes, Parameters!dg)[0] == Test14UDA2("2"));
    static assert(__traits(getAttributes, Parameters!dg)[1] == "test15yUDA");
}

void test15z()
{
    test15y((@(15) @(16) int x){
        static assert([__traits(getAttributes, x)] == [15, 16]);
    });
}

void test16x(A)(@(22) A a)
{
    static assert([__traits(getAttributes, a)] == [22]);
}

void test16()
{
    static assert([ParameterUDA!(0, test16x!int)] == [22]);
}

void test17()
{
    void test17x(A)(@(23) A a)
    {
        static assert([__traits(getAttributes, a)] == [23]);
    }
    static assert([ParameterUDA!(0, test17x!int)] == [23]);
}

void test18()
{
    void test18a(@(Tuple!(18, "a")) int a)
    {
        static assert(__traits(getAttributes, a) == Tuple!(18, "a"));
    }
    void test18b(@Tuple!(18, "b") int a)
    {
        static assert(__traits(getAttributes, a) == Tuple!(18, "b"));
    }

    static assert(ParameterUDA!(0, test18a) == Tuple!(18, "a"));
    static assert(ParameterUDA!(0, test18b) == Tuple!(18, "b"));
}

// Lambdas with parentheses:
void test19()
{
    // lambdas without parentheses
    alias test19a = @(3) b => 1 + 2;
    alias test19b = @(3) @(4) b => 1 + 2;

    alias test19c = (@(3) c, @(5) d) => 1 + 2;
    alias test19d = (@(3) @(4) c, @(5) d) => 1 + 2;
    auto test19e = (@(3) int c, @(5) int d) => 1 + 2;

    // still allow alias function declarations
    alias FuncType = @safe void function();
    alias FuncType2 = @safe nothrow void function();
    alias FuncType3 = nothrow void function();
    alias FuncType4 = nothrow @safe void function();
}

void test20()
{
    // Using a delegate with inferred parameter type
    void test20a(int delegate(int) t){ t(1); }
    test20a((@(19) a) {
        static assert([__traits(getAttributes, a)] == [19]);
        return a + 2;
    });
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=20831

void foo20831(int f, float, @("test") string s = "test") {}

static if(is(typeof(foo20831) Params20831 == __parameters))
    static assert([__traits(getAttributes, Params20831[1..2])] == []);

/************************************************/

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=15804

template test15804()
{
    alias AliasSeq(T...) = T;

    @(42) struct Foo(D) {}
    auto fooFac(T)()
    {
        static assert(__traits(getAttributes, Foo) == AliasSeq!42);
        static assert(__traits(getAttributes, Foo!int) == AliasSeq!42);
        return Foo!T();
    }

    auto booFac(T)()
    {
        @(43) struct Boo {}
        static assert(__traits(getAttributes, Boo) == AliasSeq!43);
        return Boo();
    }

    auto barFac(T)()
    {
        @(44) struct Bar(D) {}
        static assert(__traits(getAttributes, Bar) == AliasSeq!44); // Fixed
        static assert(__traits(getAttributes, Bar!int) == AliasSeq!44);
        return Bar!T();
    }

    auto bazFac(T)()
    {
        @(45) static struct Baz(D) {}
        static assert(__traits(getAttributes, Baz) == AliasSeq!45); // Fixed
        static assert(__traits(getAttributes, Baz!int) == AliasSeq!45);
        return Baz!T();
    }

    auto foo = fooFac!int;
    auto boo = booFac!int;
    auto bar = barFac!int;
    auto baz = bazFac!int;
}

alias a15804 = test15804!();

/************************************************/

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
    test9178();
    test13();
    test14();
    test16();
    test17();
    test18();
    test19();
    test20();

    printf("Success\n");
    return 0;
}
