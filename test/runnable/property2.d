// PERMUTE_ARGS: -property

extern (C) int printf(const char* fmt, ...);

// Is -property option specified?
enum enforceProperty = !__traits(compiles, {
    int prop(){ return 1; }
    int n = prop;
});

template select(alias v1, alias v2)
{
    static if (enforceProperty)
        enum select = v1;
    else
        enum select = v2;
}

struct Test(int N)
{
    int value;
    int getset;

    static if (N == 0)
    {
        ref foo(){ getset = 1; return value; }

        enum result = select!(0, 1);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "getter"
    }
    static if (N == 1)
    {
        ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 2);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "setter"
    }
    static if (N == 2)
    {
        @property ref foo(){ getset = 1; return value; }

        enum result = select!(1, 1);
        // -property    prints "getter"
        // (no option)  prints "getter"
    }
    static if (N == 3)
    {
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(2, 2);
        // -property    prints "setter"
        // (no option)  prints "setter"
    }


    static if (N == 4)
    {
        ref foo()     { getset = 1; return value; }
        ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 2);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "setter"
    }
    static if (N == 5)
    {
        @property ref foo()     { getset = 1; return value; }
                  ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 0);
        // -property    test.d(xx): Error: cannot overload both property and non-property functions
        // (no option)  test.d(xx): Error: cannot overload both property and non-property functions
    }
    static if (N == 6)
    {
                  ref foo()     { getset = 1; return value; }
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 0);
        // -property    test.d(xx): Error: cannot overload both property and non-property functions
        // (no option)  test.d(xx): Error: cannot overload both property and non-property functions
    }
    static if (N == 7)
    {
        @property ref foo()     { getset = 1; return value; }
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(2, 2);
        // -property    prints "setter"
        // (no option)  prints "setter"
    }
}

template seq(T...)
{
    alias T seq;
}
template iota(int begin, int end)
    if (begin <= end)
{
    static if (begin == end)
        alias seq!() iota;
    else
        alias seq!(begin, iota!(begin+1, end)) iota;
}

void main()
{
    foreach (N; iota!(0, 8))
    {
        printf("%d: ", N);

        Test!N s;
        static if (Test!N.result == 0)
        {
            static assert(!is(typeof({ s.foo = 1; })));
            printf("compile error\n");
        }
        else
        {
            s.foo = 1;
            if (s.getset == 1)
                printf("getter\n");
            else
                printf("setter\n");
            assert(s.getset == Test!N.result);
        }
    }
}
