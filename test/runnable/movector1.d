// REQUIRED_ARGS: -preview=moveattribute

void test1()
{
    static char[] result;

    static struct A
    {
        this(inout ref A) inout { result ~= "Cc"; }
        this(inout ref A) @move inout { result ~= "Mc"; }
    }

    static struct S
    {
        A a;
    }

    static S gs;
    static A ga;

    static T getValue(T)() { return T(); }
    static ref T getRef(T)()
    {
        static if (is(T == S)) return gs;
        else return ga;
    }

    static void test(T)()
    {
        result = null;
        T a;
        auto b = a; // Cc
        auto c = __move(a); // Mc
        assert(result == "CcMc", result);

        result = null;
        auto d = getValue!T(); // nrvo
        auto e = getRef!T(); // Cc
        auto f = __move(getRef!T()); // Mc
        assert(result == "CcMc", result);
    }

    test!A();
    test!S();
}

void test2()
{
    static struct S
    {
        static int i;
        this(ref S) @move { ++i; }
    }

    static void func(S) {}

    S a = S();
    assert(a.i == 0);
    func(S());
    assert(a.i == 0);
    func(__move(a));
    assert(a.i == 1);
    S b = __move(a);
    assert(a.i == 2);
}

void main()
{
    test1();
    test2();
}
