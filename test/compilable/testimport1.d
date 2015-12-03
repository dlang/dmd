// PERMUTE_ARGS:

module testimport1;

import imports.imp1a;

class C
{
    import imports.imp1b;

    void test()
    {
        imports.imp1b.bar();
        imports.imp1a.foo();
    }
}

int global;

void main()
{
    // From here, 1a is visible but 1b isn't.
    imports.imp1a.foo();
    static assert(!__traits(compiles, imports.imp1b.bar()));

    testimport1.C c;
    auto y1 = testimport1.global;

    // A declaration always hide same name root of package hierarchy.
    {
        int imports;
        static assert(!__traits(compiles, imports.imp1a.foo()));
    }

    // FQN access with Module Scope Operator works
    .imports.imp1a.foo();
    static assert(!__traits(compiles, { auto y2 = .testimport1.global; }));

    // FQN access through class is not allowed
    static assert(!__traits(compiles, { C.imports.imp1b.bar(); }));
}

/***************************************************/
// 12413

mixin template M12413()
{
    static import imports.imp1b;
}

class C12413
{
    mixin M12413!();

    void f()
    {
        static assert(!__traits(compiles, imports.x));
    }
}
