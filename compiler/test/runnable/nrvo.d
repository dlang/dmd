/***************************************************/

struct S1
{
    int x;
    ~this() {}
}

__gshared S1* s1ptr;

S1 test1a()
{
    auto result = S1(123);
    (() @trusted { result.x++; s1ptr = &result; })();
    return result;
}

void test1()
{
    auto r = test1a();
    assert(r.x == 124);
    assert(&r == s1ptr);
}

/***************************************************/
// https://github.com/dlang/dmd/issues/20567

struct S2
{
    int x;
    this(ref S2 s) { x = s.x; }
}

S2 returnRval(ref S2 arg1, ref S2 arg2, int i)
{
    return i ? arg1 : arg2;
}

void test2()
{
    S2 s1, s2;
    s1.x = 3;
    s2.x = 4;
    S2 s = returnRval(s1, s2, 0);
    assert(s.x == 4);
    s = returnRval(s1, s2, 1);
    assert(s.x == 3);
}

/***************************************************/

struct S3
{
    S3* ptr;

    this(int)
    {
        ptr = &this;
    }

    @disable this(this);

    void check()
    {
        assert(this.ptr is &this);
    }

    invariant(this.ptr is &this);
}

S3 make3()
{
    return S3(1);
}

__gshared int i3;
__gshared bool b3;

S3 f3()
out(v; v.ptr == &v)
{
    i3++;
    return make3();
}

S3 g3()
out(v; v.ptr == &v)
{
    return b3 ? make3() : f3();
}

void test3()
{
    S3 s1 = f3();
    s1.check();
    assert(i3 == 1);

    S3 s2 = b3 ? f3() : g3();
    s2.check();
    assert(i3 == 2);

    S3 s3 = f3();
    auto closure = { s3.check(); };
    closure();
    s3.check();
    assert(i3 == 3);
/*
    struct S3A
    {
        int a;
        S3 b;
    }

    S3A s4 = S3A(1, g3());
    s4.b.check();
    assert(i3 == 4);

    S3A f3()
    {
        return S3A(2, S3(1));
    }

    f3().b.check();
*/
}

/***************************************************/

struct S4
{
    S4* ptr;

    this(int)
    {
        ptr = &this;
    }

    this(ref inout S4)
    {
        ptr = &this;
    }

    this(S4)
    {
        ptr = &this;
    }

    void check()
    {
        assert(this.ptr is &this);
    }

    invariant(this.ptr is &this);
}

struct V4
{
    S4 s1, s2;
    this(int)
    {
        s1 = s2 = S4(1);
    }
}

S4 f4()
out(v; v.ptr == &v)
{
    return __rvalue(V4(1).s1);
}

S4 g4()
out(v; v.ptr == &v)
{
    V4 v = V4(1);
    v.s1.check();
    v.s2.check();
    S4 s = v.s1;
    return s;
}

void test4()
{
    f4().check();

    S4 s = g4();
    s.check();
}

/***************************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
}
