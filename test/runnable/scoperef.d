extern(C) int printf(const char*, ...);

/******************************************/

bool test1()
{
    struct S
    {
    static:
        // Wrap functions in inner struct to make function overloads

        auto foo   (scope ref S s) { return 1; }
        auto hoo(T)(scope ref T s) { return 1; }

        auto bar   (scope ref S s) { return 1; }
        auto bar   (          S s) { return 3; }
        auto var(T)(scope ref T s) { return 1; }
        auto var(T)(          T s) { return 3; }

        auto baw   (scope ref S s) { return 1; }
        auto baw   (      ref S s) { return 2; }
        auto vaw(T)(scope ref T s) { return 1; }
        auto vaw(T)(      ref T s) { return 2; }

        auto bay   (scope ref S s) { return 1; }
        auto bay   (      ref S s) { return 2; }
        auto bay   (          S s) { return 3; }
        auto vay(T)(scope ref T s) { return 1; }
        auto vay(T)(      ref T s) { return 2; }
        auto vay(T)(          T s) { return 3; }
    }

    S s;

    // 'scope ref' can bind both lvalue and rvalue
    S.foo(s  );
    S.foo(S());
    // 'scope ref' and template function also can do.
    S.hoo(s  );
    S.hoo(S());
    // 'scope ref' does not depends on IFTI
    alias S.hoo!S Hoo;
    Hoo(s  );
    Hoo(S());

    // overload resolution between 'scope ref' and non-ref
    // 'scope ref' is always lesser matching.
    assert(S.bar(s  ) == 1);
    assert(S.bar(S()) == 3);
    assert(S.var(s  ) == 1);
    assert(S.var(S()) == 3);

    // overload resolution between 'scope ref' and 'ref'
    // 'scope ref' is always lesser matching.
    assert(S.baw(s  ) == 2);
    assert(S.baw(S()) == 1);
    assert(S.vaw(s  ) == 2);
    assert(S.vaw(S()) == 1);

    // overload resolution between 'scope ref', 'ref', and non-ref
    // 'scope ref' is always lesser matching, then *never matches anything*.
    assert(S.bay(s  ) == 2);
    assert(S.bay(S()) == 3);
    assert(S.vay(s  ) == 2);
    assert(S.vay(S()) == 3);

    // keep right behavior: rvalues never matches to 'ref'
    struct S1 { int n; }
    struct S2 { this(int n){} }
    void baz(ref S1 s) {}
    void vaz(ref S2 s) {}
    static assert(!__traits(compiles, baz(S1(1)) ));
    static assert(!__traits(compiles, vaz(S2(1)) ));

    return true;
}
static assert(test1());     // CTFE

/******************************************/

void test2()
{
    static void foo(scope ref int x) { static assert(is(typeof(x) == int)); }
    static void bar(   in ref int x) { static assert(is(typeof(x) == const int)); }

    static assert(typeof(foo).stringof == "void(scope ref int x)");
    static assert(typeof(bar).stringof == "void(in ref int x)");
    static assert(typeof(foo).mangleof == "FMKiZv");    // 'M'==scope, 'K'==ref, 'i'==int
    static assert(typeof(bar).mangleof == "FMKxiZv");   // 'M'==scope, 'K'==ref, 'x'==const, 'i'==int,

    void voo(scope ref int x) {}
    void var(   in ref int x) {}
    static assert(foo.mangleof == "_D8scoperef5test2FZ3fooFMKiZv");
    static assert(bar.mangleof == "_D8scoperef5test2FZ3barFMKxiZv");
    static assert(voo.mangleof == "_D8scoperef5test2FZ3vooMFMKiZv");
    static assert(var.mangleof == "_D8scoperef5test2FZ3varMFMKxiZv");
}

/******************************************/

int main()
{
    test1();
    test2();

    printf("Success\n");
    return 0;
}
