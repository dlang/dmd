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

/*******************************************/

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

/*******************************************/

void test3()
{
    static struct S
    {
        static char[] r;

        this(ref inout S) inout { r ~= "Cc"; }
        this(@rvalue ref inout S) inout { r ~= "Mc"; }
        void opAssign(ref inout S) inout { r ~= "Ca"; }
        void opAssign(@rvalue ref inout S) inout { r ~= "Ma"; }
        ~this() inout { r ~= "D"; }
    }

    static S get() { return S(); }
    static void fun(S) {}

    S.r = null;
    {
        S a = get();
        S b = a; // Cc
        S c = cast(@rvalue) b; // Mc
        assert(S.r == "CcMc", S.r);
        S.r = null;

        b = get(); // MaD or DMa
        assert(S.r == "MaD" || S.r == "DMa", S.r); // inliner changes order here
        S.r = null;

        b = c; // Ca
        a = cast(@rvalue) c; // Ma
        fun(get()); // D
        fun(cast(@rvalue)b); // McD
        assert(S.r == "CaMaDMcD", S.r);
        S.r = null;

        // DDD
    }
    assert("DDD", S.r);
}

/*******************************************/

void test4()
{
    static struct A
    {
        static char[] r;

        this(@rvalue ref inout A) inout { r ~= "Mc"; }
        this(this) { r ~= "Pb"; }
        ~this() { r ~= "D"; }
    }

    static struct S
    {
        A a;
    }

    A.r = null;
    A a;
    a = cast(@rvalue)a;
    assert(A.r == "DMc", A.r);

    A.r = null;
    S b;
    b = cast(@rvalue) b;
    assert(A.r == "DMc", A.r);
}

/*******************************************/

void test5()
{
    static struct A
    {
        static char[] r;

        void opAssign(ref inout A) { r ~= "Ca"; }
        void opAssign(@rvalue ref inout A) { r ~= "Ma"; }
    }

    // ensure field opAssign is called
    {
        static struct S
        {
            A a;
            ~this() {}
        }

        A.r = null;
        S b;
        b = cast(@rvalue) b;
        b = b;
        assert(A.r == "MaCa", A.r);
    }

    // ensure field opAssign is called
    {
        static struct S1
        {
            A a;
            this(@rvalue ref inout typeof(this)) {}
            this(ref inout typeof(this)) {}
            ~this() {}
        }

        A.r = null;
        S1 b;
        b = cast(@rvalue) b;
        b = b;
        assert(A.r == "MaCa", A.r);
    }

    // ensure field opAssign is overridden
    {
        static struct S2
        {
            A a;
            void opAssign(@rvalue ref inout typeof(this)) {}
            void opAssign(ref inout typeof(this)) {}
        }

        A.r = null;
        S2 b;
        b = cast(@rvalue) b;
        b = b;
        assert(A.r == null, A.r);
    }
}

/*******************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
}
