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

void main()
{
    test22323();
}
