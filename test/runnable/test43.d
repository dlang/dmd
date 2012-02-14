// EXTRA_SOURCES: imports/test7494a.d imports/test7494b.d
module test43;

/***************************************************/
// Bugzilla 7494

string foo7494()
{
    return "test43.foo7494";
}

void test1()
{
    assert(foo7494() == "test43.foo7494");

    string foo7494()
    {
        return "test43.test1.foo7494";
    }
    assert(foo7494() == "test43.test1.foo7494");
    assert(.foo7494() == "test43.foo7494");
    assert(test43.foo7494() == "test43.foo7494");

    void nested()
    {
        assert(foo7494() == "test43.test1.foo7494");
        assert(.foo7494() == "test43.foo7494");
        assert(test43.foo7494() == "test43.foo7494");

        import imports.test7494a;
        assert(foo7494() == "imports.test7494a.foo7494");
        assert(.foo7494() == "test43.foo7494");
        assert(test43.foo7494() == "test43.foo7494");

        import imports.test7494b : foo7494;
        assert(foo7494() == "imports.test7494b.foo7494");
        assert(imports.test7494b.foo7494() == "imports.test7494b.foo7494");
        // Bugzilla 7496
        version (none)
            static assert(!__traits(compiles, imports.test7494b.foo7494()));
        assert(.foo7494() == "test43.foo7494");
        assert(test43.foo7494() == "test43.foo7494");
    }
    nested();

    static assert(!__traits(compiles, imports.test7494a.foo7494()));
    static assert(!__traits(compiles, imports.test7494b.foo7494()));

    import imports.test7494a;
    assert(foo7494() == "test43.test1.foo7494");
    assert(imports.test7494a.foo7494() == "imports.test7494a.foo7494");
    assert(.foo7494() == "test43.foo7494");
    assert(test43.foo7494() == "test43.foo7494");

    import imports.test7494b : foo7494;
    // ambiguous test43.test1.foo7494 and imports.test7494b.foo7494 overload
    static assert(!__traits(compiles, foo7494()));
    assert(imports.test7494a.foo7494() == "imports.test7494a.foo7494");
    assert(.foo7494() == "test43.foo7494");
    assert(test43.foo7494() == "test43.foo7494");
}

/***************************************************/

void main()
{
    test1();
}
