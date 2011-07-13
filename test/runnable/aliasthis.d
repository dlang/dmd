
import std.c.stdio;

struct Tup(T...)
{
    T field;
    alias field this;

    bool opEquals()(auto ref Tup rhs) const
    {
        foreach (i, _; rhs)
            if (field[i] != rhs.field[i])
                return false;
        return true;
    }
}

Tup!T tup(T...)(T fields)
{
    return typeof(return)(fields);
}

template Seq(T...)
{
    alias T Seq;
}

/**********************************************/

struct S
{
    int x;
    alias x this;
}

int foo(int i)
{
    return i * 2;
}

void test1()
{
    S s;
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

class C
{
    int x;
    alias x this;
}

void test2()
{
    C s = new C();
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

void test3()
{
    Tup!(int, double) t;
    t[0] = 1;
    t[1] = 1.1;
    assert(t[0] == 1);
    assert(t[1] == 1.1);
    printf("%d %g\n", t[0], t[1]);
}

/**********************************************/

struct Iter
{
    bool empty() { return true; }
    void popFront() { }
    ref Tup!(int, int) front() { return *new Tup!(int, int); }
    ref Iter opSlice() { return this; }
}

void test4()
{
    foreach (a; Iter()) { }
}

/**********************************************/

void test5()
{
    static struct Double1 {
        double val = 1;
        alias val this;
    }
    static Double1 x() { return Double1(); }
    x()++;
}

/**********************************************/

void func6(int n, string s)
{
    assert(n == 10);
    assert(s == "str");
}

void test6_1()
{
    auto t = Tup!(int, string)(10, "str");
    func6(t);   // t -> t.field
}

int func6_21(int n, string s){ return 1; }

int func6_22(int n, string s){ return 1; }
int func6_22(Tup!(int, string) t){ return 2; }

int func6_23(string s, int n){ return 1; }

void test6_2()
{
    auto t = Tup!(int, string)(10, "str");
    assert(func6_21(t) == 1);

    assert(func6_22(t) == 2);

    static assert(!__traits(compiles, func6_23(t)));
}

/**********************************************/

alias Seq!(int, string) Field7;

void test7_1()
{
    auto t = Tup!(int, string)(10, "str");
    Field7 field = t;           // NG -> OK
    assert(field[0] == 10);
    assert(field[1] == "str");
}

void test7_2()
{
    auto t = Tup!(int, string)(10, "str");
    Field7 field = t.field;     // NG -> OK
    assert(field[0] == 10);
    assert(field[1] == "str");
}

void test7_3()
{
    auto t = Tup!(int, string)(10, "str");
    Field7 field;
    field = t.field;
    assert(field[0] == 10);
    assert(field[1] == "str");
}

/**********************************************/

void test8_1()
{
    auto t = Tup!(Tup!(int, double), string)(tup(10, 3.14), "str");

    Seq!(int, double, string) fs1 = t;
    assert(fs1[0] == 10);
    assert(fs1[1] == 3.14);
    assert(fs1[2] == "str");

    Seq!(Tup!(int, double), string) fs2 = t;
    assert(fs2[0][0] == 10);
    assert(fs2[0][1] == 3.14);
    assert(fs2[0] == tup(10, 3.14));
    assert(fs2[1] == "str");

    Tup!(Tup!(int, double), string) fs3 = t;
    assert(fs3[0][0] == 10);
    assert(fs3[0][1] == 3.14);
    assert(fs3[0] == tup(10, 3.14));
    assert(fs3[1] == "str");
}

void test8_2()
{
    auto t = Tup!(Tup!(int, double), Tup!(string, int[]))(tup(10, 3.14), tup("str", [1,2]));

    Seq!(int, double, string, int[]) fs1 = t;
    assert(fs1[0] == 10);
    assert(fs1[1] == 3.14);
    assert(fs1[2] == "str");
    assert(fs1[3] == [1,2]);

    Seq!(int, double, Tup!(string, int[])) fs2 = t;
    assert(fs2[0] == 10);
    assert(fs2[1] == 3.14);
    assert(fs2[2] == tup("str", [1,2]));

    Seq!(Tup!(int, double), string, int[]) fs3 = t;
    assert(fs3[0] == tup(10, 3.14));
    assert(fs3[0][0] == 10);
    assert(fs3[0][1] == 3.14);
    assert(fs3[1] == "str");
    assert(fs3[2] == [1,2]);
}

/**********************************************/

void test9_1a()
{
    auto t = tup(10, "str");

    size_t i = 0;
    foreach (e; t)
    {
        pragma(msg, "[] = ", typeof(e));
        static if (is(typeof(e) == int   )) assert(i == 0 && e == 10);
        static if (is(typeof(e) == string)) assert(i == 1 && e == "str");
        ++i;
    }
}

void test9_1b()
{
    auto t = tup(10, "str");

    foreach (i, e; t)
    {
        pragma(msg, "[", cast(int)i, "] = ", typeof(e));
        static if (is(typeof(e) == int   )) { static assert(i == 0); assert(e == 10); }
        static if (is(typeof(e) == string)) { static assert(i == 1); assert(e == "str"); }
    }
}

void test9_2a()
{
    auto t = tup(10, "str");

    size_t i = 1;
    foreach_reverse (e; t)
    {
        pragma(msg, "[] = ", typeof(e));
        static if (is(typeof(e) == int   )) assert(i == 0 && e == 10);
        static if (is(typeof(e) == string)) assert(i == 1 && e == "str");
        --i;
    }
}

void test9_2b()
{
    auto t = tup(10, "str");

    foreach_reverse (i, e; t)
    {
        pragma(msg, "[", cast(int)i, "] = ", typeof(e));
        static if (is(typeof(e) == int   )) { static assert(i == 0); assert(e == 10); }
        static if (is(typeof(e) == string)) { static assert(i == 1); assert(e == "str"); }
    }
}

/**********************************************/

void test10()
{
    foreach (i, e; tup(tup(10, 3.14), tup("str", [1,2])))
    {
        static if (i == 0) assert(e == tup(10, 3.14));
        static if (i == 1) assert(e == tup("str", [1,2]));
    }

    foreach (i, e; tup(10, tup(3.14, tup("str", tup([1,2])))))
    {
        static if (i == 0) assert(e == 10);
        static if (i == 1) assert(e == tup(3.14, tup("str", tup([1,2]))));
    }
}

/**********************************************/

void tfunc11(A, B)(A a, B b)
{
    assert(a == 10);
    assert(b == "str");
}

void test11()
{
    auto t = tup(10, "str");
    tfunc11(t);
}

/**********************************************/

void test12()
{
    auto t1 = Tup!(Tup!(int, double), Tup!(string, int[]))(tup(10, 3.14), tup("str", [1,2]));
    auto t2 = Tup!(int, double, string, int[])(t1);
    // expand on struct literal syntax

    assert(t2[0] == 10);
    assert(t2[1] == 3.14);
    assert(t2[2] == "str");
    assert(t2[3] == [1,2]);
}

/**********************************************/

void test13()
{
    auto t = Tup!(int, double, string, int[])(10, 3.14, "str", [1,2]);
    auto f1 = t[];
    assert(f1[0] == 10);
    assert(f1[1] == 3.14);
    assert(f1[2] == "str");
    assert(f1[3] == [1,2]);

    auto f2 = t[1..3];
    assert(f2[0] == 3.14);
    assert(f2[1] == "str");
}

/**********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6_1();
    test6_2();
    test7_1();
    test7_2();
    test7_3();
    test8_1();
    test8_2();
    test9_1a();
    test9_1b();
    test9_2a();
    test9_2b();
    test10();
    test11();
    test12();
    test13();

    printf("Success\n");
    return 0;
}
