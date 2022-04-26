version(Windows)
    enum EXPORT = "export ";
else
    enum EXPORT = "";

// https://issues.dlang.org/show_bug.cgi?id=22323
extern(C++) class C22323
{
    this();
    ~this();

    mixin(EXPORT ~ q{static extern __gshared int ctorCount;});
    mixin(EXPORT ~ q{static extern __gshared int dtorCount;});
}

extern(C++) struct S22323
{
    this(int dummy);
    ~this();

    mixin(EXPORT ~ q{static extern __gshared int ctorCount;});
    mixin(EXPORT ~ q{static extern __gshared int dtorCount;});
}

void test22323()
{
    import cppnew;

    assert(C22323.ctorCount == 0);
    assert(C22323.dtorCount == 0);
    C22323 o = cpp_new!C22323;
    assert(C22323.ctorCount == 1);
    assert(C22323.dtorCount == 0);
    cpp_delete(o);
    assert(C22323.ctorCount == 1);
    assert(C22323.dtorCount == 1);

    o = new C22323;
    assert(C22323.ctorCount == 2);
    assert(C22323.dtorCount == 1);
    o.destroy;
    assert(C22323.ctorCount == 2);
    assert(C22323.dtorCount == 2);

    assert(S22323.ctorCount == 0);
    assert(S22323.dtorCount == 0);
    {
        S22323 s = S22323(0);
        assert(S22323.ctorCount == 1);
        assert(S22323.dtorCount == 0);
    }
    assert(S22323.ctorCount == 1);
    assert(S22323.dtorCount == 1);

    S22323 *s = cpp_new!S22323(0);
    assert(S22323.ctorCount == 2);
    assert(S22323.dtorCount == 1);
    cpp_delete(s);
    assert(S22323.ctorCount == 2);
    assert(S22323.dtorCount == 2);

    s = new S22323(0);
    assert(S22323.ctorCount == 3);
    assert(S22323.dtorCount == 2);
    (*s).destroy();
    assert(S22323.ctorCount == 3);
    assert(S22323.dtorCount == 3);
}

// https://issues.dlang.org/show_bug.cgi?id=19660
extern (C)
{
    export extern __gshared int someValue19660;
    export void setSomeValue19660(int v);
    export int getSomeValue19660();
}

extern (C++)
{
    export extern __gshared int someValueCPP19660;
    export void setSomeValueCPP19660(int v);
    export int getSomeValueCPP19660();
}

void test19660()
{
    assert(someValue19660 == 0xF1234);
    assert(getSomeValue19660() == 0xF1234);
    setSomeValue19660(100);
    assert(someValue19660 == 100);
    assert(getSomeValue19660() == 100);
    someValue19660 = 200;
    assert(someValue19660 == 200);
    assert(getSomeValue19660() == 200);

    assert(someValueCPP19660 == 0xF1234);
    assert(getSomeValueCPP19660() == 0xF1234);
    setSomeValueCPP19660(100);
    assert(someValueCPP19660 == 100);
    assert(getSomeValueCPP19660() == 100);
    someValueCPP19660 = 200;
    assert(someValueCPP19660 == 200);
    assert(getSomeValueCPP19660() == 200);
}

void main()
{
    test22323();
    test19660();
}
