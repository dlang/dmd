// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

/**********************************************/

enum Bar
{
    bar2 = 2,
    bar3,
    bar4 = 0
}

void test1()
{
    Bar b;

    assert(b == 2);
}

/**********************************************/

void test2()
{
    enum E
    {
        a=-1
    }

    assert(E.min == -1);
    assert(E.max == -1);
}


/**********************************************/

void test3()
{
    enum E
    {
        a = 1,
        b = -1,
        c = 3,
        d = 2
    }

    assert(E.min == -1);
    assert(E.max == 3);
}

/**********************************************/

void test4()
{
    enum E
    {
        a = -1,
        b = -1,
        c = -3,
        d = -3
    }

    assert(E.min==-3);
    assert(E.max==-1);
}

/**********************************************/

enum Enum5
{
    A = 3,
    B = 10,
    E = -5,
}

void test5()
{
    assert(Enum5.init == Enum5.A);
    assert(Enum5.init == 3);
    Enum5 e;
    assert(e == Enum5.A);
    assert(e == 3);
}

/***********************************/

enum E6 : byte
{
    NORMAL_VALUE = 0,
    REFERRING_VALUE = NORMAL_VALUE + 1,
    OTHER_NORMAL_VALUE = 2
}

void foo6(E6 e)
{
}

void test6()
{
     foo6(E6.NORMAL_VALUE);
     foo6(E6.REFERRING_VALUE);
     foo6(E6.OTHER_NORMAL_VALUE);
}

/**********************************************/
// 3096

void test3096()
{
    template Tuple(T...) { alias Tuple = T; }

    template Base(E)
    {
        static if(is(E B == enum))
            alias Base = B;
    }

    template GetEnum(T)
    {
        enum GetEnum { v = T.init }
    }

    struct S { }
    class C { }

    foreach (Type; Tuple!(char, wchar, dchar, byte, ubyte,
                          short, ushort, int, uint, long,
                          ulong, float, double, real, S, C))
    {
        static assert(is(Base!(GetEnum!Type) == Type));
    }
}

/**********************************************/
// 7719

enum foo7719 = bar7719;
enum { bar7719 = 1 }

/**********************************************/
// 9845

enum { A9845 = B9845 }
enum { B9845 = 1 }

/**********************************************/
// 9846

const int A9846 = B9846;
enum { B9846 = 1 }

/**********************************************/
// 10105

enum E10105 : char[1] { a = "a" }

/**********************************************/
// 10113

enum E10113 : string
{
    a = "a",
    b = "b",
    abc = "abc"
}

void test10113()
{
    E10113 v = E10113.b;
    bool check = false;

    final switch (v) {
    case E10113.a: assert(false);
    case E10113.b: check = true; break;
    case E10113.abc: assert(false);
    }

    assert(check);
}

/**********************************************/
// 10503

@property int octal10503(string num)()
{
    return num.length;
}

enum
{
    A10503 = octal10503!"2000000",
    B10503 = octal10503!"4000",
}

/**********************************************/
// 10505

enum
{
    a10505 = true,
    b10505 = 10.0f,
    c10505 = false,
    d10505 = 10,
    e10505 = null
}

static assert(is(typeof(a10505) == bool));
static assert(is(typeof(b10505) == float));
static assert(is(typeof(c10505) == bool));
static assert(is(typeof(d10505) == int));
static assert(is(typeof(e10505) == typeof(null)));

/**********************************************/
// 10561

void test10561()
{
    template Tuple(T...) { alias Tuple = T; }

    foreach (Type; Tuple!(char, wchar, dchar, byte, ubyte,
                          short, ushort, int, uint, long,
                          ulong, float, double, real))
    {
        enum : Type { v = 0, w = 0, x, y = x }
        static assert(is(typeof(v) == Type));
        static assert(is(typeof(w) == Type));
        static assert(is(typeof(x) == Type));
        static assert(is(typeof(y) == Type));
    }

    class B { }
    class D : B { }
    enum : B { a = new D, b = new B, c = null }
    static assert(is(typeof(a) == B));
    static assert(is(typeof(b) == B));
    static assert(is(typeof(c) == B));

    struct S { this(int) { } }
    enum : S { d = S(1), e = S(2) }
    static assert(is(typeof(d) == S));
    static assert(is(typeof(e) == S));

    enum : float[] { f = [], g = [1.0, 2.0], h = [1.0f] }
    static assert(is(typeof(f) == float[]));
    static assert(is(typeof(g) == float[]));
    static assert(is(typeof(h) == float[]));
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
    test10113();
    test10561();

    printf("Success\n");
    return 0;
}


