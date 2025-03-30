/*
TEST_OUTPUT:
---
hello
hello



hello
hello
---

RUN_OUTPUT:
---
31
42
53
64
75
86
97
108
119
1210
5
test4
Constructor
  Inside Scope
Destructor
hey
Success
---
*/
import core.stdc.stdio;

/*********************************************/

int foo(int x)
{
    return mixin("x + 1"w);
}

void test1()
{
    assert(foo(3) == 4);
}

/*********************************************/

void test2()
{
    int j;
    mixin("
        int x = 3;
        for (int i = 0; i < 10; i++)
            printf(\"%d%d\n\", x + i, ++j);
        ");
    assert(j == 10);
}

/*********************************************/

mixin("int abc3 = 5;");

void test3()
{
    printf("%d\n", abc3);
    assert(abc3 == 5);
}

/*********************************************/

mixin("
void test4()
{
    printf(\"test4\n\");
" ~ "}");

/*********************************************/

int x5;

class Foo5
{
        this () scope
        {
                printf ("Constructor\n");
                assert(x5 == 0);
                x5++;
        }
        ~this () scope
        {
                printf ("Destructor\n");
                assert(x5 == 2);
                x5++;
        }
}

void test5()
{
    {
        mixin ("scope Foo5 f = new Foo5;\n");
        printf ("  Inside Scope\n");
        assert(x5 == 1);
        x5++;
    }
    assert(x5 == 3);
}

/*********************************************/

void test6()
{
    static const b = "printf(`hey\n`);";

    if (true)
        mixin(b);
}

/*********************************************/

template Foo7(alias f)
{
}

class Bar7
{
        mixin Foo7!( function {} );
}

void test7()
{
}

/*********************************************/

template TupleDecls(T, R ...) {
    T value;
    static if (R.length)
        mixin TupleDecls!(R) Inner;
}

struct TupleStruct(T ...) { mixin TupleDecls!(T); }

void test8() {
    alias TupleStruct!(char[], char[]) twoStrings;
}

/*********************************************/

template Magic()
{
    void* magic = null;
}

struct Item
{
    mixin Magic A;
}

struct Foo9(alias S)
{
}

void test9()
{
    Foo9!(Item.A) bar;
}

/*********************************************/

pragma(msg, "hello");
pragma(msg, ['h', 'e', 'l', 'l', 'o']);
pragma(msg, "");
pragma(msg, []);
pragma(msg, null);
mixin("string hello;");
mixin(['i', 'n', 't', ' ', 't', 'e', 's', 't', '1', '0', 'x', ';']);
mixin("");
mixin([]);
mixin(null);
void test10()
{
    pragma(msg, "hello");
    pragma(msg, ['h', 'e', 'l', 'l', 'o']);
    pragma(msg, "");
    pragma(msg, []);
    pragma(msg, null);
    mixin("string hello;");
    mixin(['i', 'n', 't', ' ', 'a', ';']);
    mixin("");
    mixin([]);
    mixin(null);
}

/*********************************************/
// https://issues.dlang.org/show_bug.cgi?id=7560

class Base7560
{
    template getter(T)
    {
        void get(ref T[] i, uint n) {}
    }
    mixin getter!uint;
    mixin getter!char;
}

class Derived7560 : Base7560
{
    alias Base7560.get get;
    void get(ref char[] x) {}
}

/*********************************************/
// https://issues.dlang.org/show_bug.cgi?id=10577

enum sync10577;

public template get_sync10577(size_t I, A...)
{
    static if (I == A.length)               enum bool get_sync10577 = false;
    else static if (is(A[I] == sync10577))  enum bool get_sync10577 = true;
    else                                    enum bool get_sync10577 = get_sync!10577(I+1, A);
}

template add_sync10577(T, size_t ITER=0)
{
    static if (ITER == (__traits(derivedMembers, T).length))
    {
        enum string add_sync10577 = "";
    }
    else
    {
        enum string mem = __traits(derivedMembers, T)[ITER];
        enum string add_sync10577 =
            "static if (! __traits(isVirtualMethod, " ~ mem ~ ")) {" ~
            "mixin(add_sync10577!(get_sync10577!(0, __traits(getAttributes, "
            ~ mem ~ ")), \"" ~ mem ~ "\"));} " ~ add_sync10577!(T, ITER+1);
    }
}

template add_sync10577(bool A, string M)
{
    static if (A)
    {
        enum string add_sync10577 = " auto " ~ M[1..$] ~
            "() { synchronized(this) return " ~ M ~ "; }";
    }
    else
    {
        enum string add_sync10577 = "";
    }
}

class base10577
{
    public void foo() {}
}

class derived10577 : base10577
{
    mixin(add_sync10577!(derived10577));
    @sync10577 private bool _bar;

    public override void foo() {}
}

/*********************************************/
// https://issues.dlang.org/show_bug.cgi?id=10583

enum sync10583;

public template get_sync10583(size_t I, A...)
{
    static if (I == A.length)
        enum bool get_sync10583 = false;
    else static if (is(A[I] == sync10583))
        enum bool get_sync10583 = true;
    else
        enum bool get_sync10583 = get_sync10583!(I+1, A);
}

template add_sync10583(T, size_t ITER = 0)
{
    static if (ITER == (__traits(derivedMembers, T).length))
    {
        enum string add_sync10583 = "";
    }
    else
    {
        enum string mem = __traits(derivedMembers, T)[ITER];
        enum string add_sync10583 =
            "mixin(add_sync10583!(get_sync10583!(0, __traits(getAttributes, "
            ~ mem ~ ")), __traits(getProtection, "
            ~ mem ~ "), \"" ~ mem ~ "\"));\n" ~ add_sync10583!(T, ITER+1);
    }
}

template add_sync10583(bool A, string P, string M)
{
    static if (A)
    {
        enum string add_sync10583 = " auto " ~ M[1..$] ~
            "() { synchronized(this) return " ~ M ~ "; }";
    }
    else
        enum string add_sync10583 = "";
}

class derived10583
{
    mixin(add_sync10583!(derived10583));
    @sync10583 private bool _bar;
    void frop() {}
}

/*********************************************/

string rep(string s, int n)
{
    return n > 1 ? s ~ rep(s, n-1) : s;
}

void test7156()
{
    int i;
    mixin(rep("++i;", 200));
}

/*********************************************/
// https://issues.dlang.org/show_bug.cgi?id=7553

template Foo7553()
{
    struct Range7553 {}
}
template Biz7553()
{
    struct Range7553 {}
}

class Bar7553
{
    mixin Foo7553!() index0;
    mixin Biz7553!() index1;

    auto to_range(Range)(Range r)
    {
        return r;
    }

}

void test7553()
{
    auto r2 = new Bar7553().to_range(1);
}

/*********************************************/
// https://issues.dlang.org/show_bug.cgi?id=13479

mixin template F13479()
{
    void t()()
    {
    }

    alias t!() a;
}

void test13479()
{
    mixin F13479!();
    a();
}

/*********************************************/

void main()
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
    test7156();
    test13479();

    printf("Success\n");
}
