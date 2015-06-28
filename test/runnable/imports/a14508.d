module imports.a14508;

void unlinked() {}

struct Foo1()
{
    void func() {}

    version(unittest) void test()
    {
        UUint.testImpl();
    }
    unittest
    {
        UUint.testImpl();
    }
}

struct Foo2()
{
    void func() {}
}

version(unittest)
{
    template UnittestUtil(T)
    {
        void testImpl()
        {
        }
    }

    // Those are treated as instantiations in root module, when `dmd -unittest link14508.d`.
    alias F1 = Foo1!();
    alias F2 = Foo2!();
    alias UUint = UnittestUtil!int;
}

struct Bar1()
{
    void func() {}

    debug void test()
    {
        DUint.testImpl();
    }
}

struct Bar2()
{
    void func() {}
}

debug
{
    template DebugUtil(T)
    {
        void testImpl()
        {
        }
    }

    // Those are treated as instantiations in root module, when `dmd -debug link14508.d`.
    alias B1 = Bar1!();
    alias B2 = Bar2!();
    alias DUint = DebugUtil!int;
}
