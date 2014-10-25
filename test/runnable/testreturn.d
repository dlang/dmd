extern(C) int printf(const char*, ...);

alias TypeTuple(T...) = T;

/***************************************************/
// 13336

struct S13336
{
    int opApply(scope int delegate(int) dg)
    {
        return dg(0);
    }
}

double result13336;

enum fbody13336 =
q{
    static if (n == 1)
    {
        if (f)
            return sx;
        return sy;
    }
    static if (n == 2)
    {
        foreach (e; S13336())
        {
            if (f)
                return sx;
            return sy;
        }
        assert(0);
    }
    static if (n == 3)
    {
        if (f)
            return sx;
        foreach (e; S13336())
        {
            return sy;
        }
        assert(0);
    }
    static if (n == 4)
    {
        foreach (e; S13336())
        {
            if (f)
                return sx;
        }
        return sy;
    }
    static if (n == 5)
    {
        if (false)
            return 99;
        foreach (e; S13336())
        {
            if (f)
                return sx;
            return sy;
        }
        assert(0);
    }
    static if (n == 6)
    {
        foreach (e; S13336())
        {
            if (f)
                return sx;
            return sy;
        }
        return 99;
    }
};

// auto ref without out contract
auto ref f13336a(int n, alias sx, alias sy)(bool f)
{
    mixin(fbody13336);
}

// auto without out contract
auto f13336b(int n, alias sx, alias sy)(bool f)
{
    mixin(fbody13336);
}

// auto ref with out contract
auto ref f13336c(int n, alias sx, alias sy)(bool f)
out(r)
{
    static assert(is(typeof(r) == const double));
    assert(r == (f ? sx : sy));
    result13336 = r;
}
body
{
    mixin(fbody13336);
}

// auto with out contract
auto f13336d(int n, alias sx, alias sy)(bool f)
out(r)
{
    static assert(is(typeof(r) == const double));
    assert(r == (f ? sx : sy));
    result13336 = r;
}
body
{
    mixin(fbody13336);
}

void test13336()
{
    static int sx = 1;
    static double sy = 2.5;

    foreach (num; TypeTuple!(1, 2, 3, 4, 5, 6))
    {
        foreach (foo; TypeTuple!(f13336a, f13336b))
        {
            alias fooxy = foo!(num, sx, sy);
            static assert(is(typeof(&fooxy) : double function(bool)));
            assert(fooxy(1) == 1.0);
            assert(fooxy(0) == 2.5);

            alias fooyx = foo!(num, sy, sx);
            static assert(is(typeof(&fooyx) : double function(bool)));
            assert(fooyx(1) == 2.5);
            assert(fooyx(0) == 1.0);
        }

        foreach (foo; TypeTuple!(f13336c, f13336d))
        {
            alias fooxy = foo!(num, sx, sy);
            static assert(is(typeof(&fooxy) : double function(bool)));
            assert(fooxy(1) == 1.0 && result13336 == 1.0);
            assert(fooxy(0) == 2.5 && result13336 == 2.5);

            alias fooyx = foo!(num, sy, sx);
            static assert(is(typeof(&fooyx) : double function(bool)));
            assert(fooyx(1) == 2.5 && result13336 == 2.5);
            assert(fooyx(0) == 1.0 && result13336 == 1.0);
        }
    }
}

/***************************************************/

int main()
{
    test13336();

    printf("Success\n");
    return 0;
}
