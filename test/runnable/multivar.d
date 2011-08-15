
extern (C) int printf(const(char*) fmt, ...);

struct Tup(T...)
{
    T field;
    alias field this;

    bool opEquals()(auto ref Tup rhs) const
    {
        foreach (i, _; T)
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

void test1()
{
    auto (num, str) = Seq!(10, "str");
    assert(num == 10);
    assert(str == "str");

    int eval = 0;
    auto (n, t) = (eval++, tup(10, tup("str", [1,2])));
    assert(eval == 1);
    assert(n == 10);
    eval = 0;
    auto (s, a) = (eval++, t);
    assert(eval == 1);
    assert(s == "str");
    assert(a == [1,2]);

    auto (i, j) = 10;
    assert(i == 10);
    assert(j == 10);

    auto (t1, t2) = tup(1, "str", [1,2]);
    assert(t1 == tup(1, "str", [1,2]));
    assert(t2 == tup(1, "str", [1,2]));

    auto (x) = 1;
    assert(x == 1);
}

/**********************************************/

void test2()
{
    auto (n, m) = [1,2];
    assert(n == 1);
    assert(m == 2);

    int[2] sa = [1,2];
    auto (x, y) = sa;
    assert(x == 1);
    assert(y == 2);
}

/**********************************************/

void test3()
{
    alias tup tuple;
    alias Seq TypeTuple;

    // Example of 1
    {
        auto (i, j) = tuple(10, "a");
        static assert(is(typeof(i) == int));
        static assert(is(typeof(j) == string));

        const (x, y) = TypeTuple!(1, 2);
        static assert(is(typeof(x) == const(int)));
        static assert(is(typeof(y) == const(int)));
    }

    {
        // Example of 2-1
        (int i, string j) = tuple(10, "a");
        static assert(is(typeof(i) == int));
        static assert(is(typeof(j) == string));

        // Example of 2-2
        (auto c, r) = TypeTuple!('c', "har");
        static assert(is(typeof(c) == char));
        static assert(is(typeof(r) == string));

        (const x, auto y) = TypeTuple!(1, 2);
        static assert(is(typeof(x) == const(int)));
        static assert(is(typeof(y) == int));

        (auto a1, const int[] a2) = TypeTuple!([1], [2,3]);
        static assert(is(typeof(a1) == int[]));
        static assert(is(typeof(a2) == const(int[])));
    }
}

/**********************************************/

void test4()
{
    auto (x, y, z) = Seq!(10, tup("a", [1,2]));
    assert(x == 10);
    assert(y == "a");
    assert(z == [1,2]);
}

/**********************************************/

void test5()
{
    auto t = tup(10, "a");

    auto (a1) = t[0..1];
    assert(a1 == 10);

    (auto a2) = t[0..1];
    assert(a2 == 10);

    auto (x1) = [10];
    assert(x1 == 10);

    (auto x2) = tup(10);
    assert(x2 == 10);

    (auto x3) = tup(10)[0..1];
    assert(x3 == 10);

    (int x4) = Seq!(10);
    assert(x4 == 10);

    // isolated comma parsing
    (int n,) = tup(10);
    assert(n == 10);

    auto (x, y,) = tup(10, 20);
    assert(x == 10);
    assert(y == 20);
}

/**********************************************/

void test6()
{
    const(int x, string y) = tup(10, "a");
    static assert(is(typeof(x) == const(int)));
    static assert(is(typeof(y) == const(string)));
    assert(x == 10);
    assert(y == "a");

    (int i, double j, string k) = tup(tup(10, 2.2), "a");
    static assert(is(typeof(i) == int));
    static assert(is(typeof(j) == double));
    static assert(is(typeof(k) == string));
    assert(i == 10);
    assert(j == 2.2);
    assert(k == "a");
}

/**********************************************/

Tup!(int, string) func7(){ return tup(10, "str"); }

auto (num71, str71) = func7();
const (num72, str72) = Seq!(10, "str");

enum (num73, str73) = func7();

void test7()
{
    assert(num71 == 10);
    assert(str71 == "str");
    num71 = 20;
    str71 = "hello";

    assert(num72 == 10);
    assert(str72 == "str");
    static assert(!__traits(compiles, num72 = 20));
    static assert(!__traits(compiles, str72 = "hello"));
    auto pnum72 = &num72;
    auto pstr72 = &str72;

    static assert(num73 == 10);
    static assert(str73 == "str");
    static assert(!__traits(compiles, num73 = 20));
//  static assert(!__traits(compiles, str73 = "hello"));
    static assert(!__traits(compiles, &num73));
//  static assert(!__traits(compiles, &str73));
}

/**********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();

    printf("Success\n");
    return 0;
}
