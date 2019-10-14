// REQUIRED_ARGS: -preview=rvaluetype

void test1()
{
    static char[] result;

    static struct A
    {
        this(inout ref A) inout { result ~= "Cc"; }
        this(inout @rvalue ref A) inout { result ~= "Mc"; }
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
    static ref @rvalue(T) getRvalueRef(T)()
    {
        static if (is(T == S))
            return cast(@rvalue)gs;
        else
            return cast(@rvalue)ga;
    }

    static void test(T)()
    {
        result = null;
        T a;
        auto b = a; // Cc
        auto c = cast(@rvalue)a; // Mc
        assert(result == "CcMc");

        result = null;
        auto d = getValue!T(); // nrvo
        auto f = getRvalueRef!T(); // Mc
        auto e = getRef!T(); // Cc
        assert(result == "McCc");
    }

    test!A();
    test!S();
}

void test2()
{
    static struct S
    {
        static int i;
        this(@rvalue ref S) { ++i; }
    }

    static void func(S) {}

    S a = S();
    assert(a.i == 0);
    func(S());
    assert(a.i == 0);
    func(cast(@rvalue)a);
    assert(a.i == 1);
    S b = cast(@rvalue)a;
    assert(a.i == 2);
}

void main()
{
    test1();
    test2();
}
