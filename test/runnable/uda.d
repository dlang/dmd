
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
// 9178

void test9178()
{
    static class Foo { @(1) int a; }

    Foo foo = new Foo;
    static assert(__traits(getAttributes, foo.tupleof[0])[0] == 1);
}

/************************************************/
// 9741

struct Bug9741
{
    pragma(msg, __traits(getAttributes, enum_field));
    alias Tuple!(__traits(getAttributes, enum_field)) Tenum_field;
    private @(10) enum enum_field = 42;

    static assert(Tenum_field[0] == 10);
    static assert(__traits(getAttributes, enum_field)[0] == 10);
    static assert(__traits(getProtection, enum_field) == "private");
    static assert(__traits(isSame, __traits(parent, enum_field), Bug9741));
    static assert(__traits(isSame, enum_field, enum_field));

    pragma(msg, __traits(getAttributes, anon_enum_member));
    alias Tuple!(__traits(getAttributes, anon_enum_member)) Tanon_enum_member;
    private @(20) enum {anon_enum_member}

    static assert(Tanon_enum_member[0] == 20);
    static assert(__traits(getAttributes, anon_enum_member)[0] == 20);
    static assert(__traits(getProtection, anon_enum_member) == "private");
    static assert(__traits(isSame, __traits(parent, anon_enum_member), Bug9741));
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
    static assert(__traits(isSame, __traits(parent, anon_enum_member_2), Bug9741));
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

    printf("Success\n");
    return 0;
}
