// REQUIRED_ARGS: -Icompilable/extra-files
// PERMUTE_ARGS:
// EXTRA_SOURCE: extra-files/pkg_import3a/package.d
// EXTRA_SOURCE: extra-files/pkg_import3a/mod.d

/******************************************/
// Test1

class Test1A
{
    import pkg_import3a;        // foo()==1, bar()==2
    class C
    {
        import pkg_import3a.mod;    // bar()==3
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3a
            assert(bar() == 3);                     // OK, bar in pkg_import3a.mod

            static assert(!__traits(compiles, pkg_import3a.foo()));
            static assert(!__traits(compiles, pkg_import3a.bar()));
            // --> both NG, inner sub-module import hides outer package.d FQN

            assert(pkg_import3a.mod.bar() == 3);    // OK, bar in pkg_import3a.mod
        }
    }
}
class Test1B
{
    class C
    {
        import pkg_import3a;        // foo()==1, bar()==2
        import pkg_import3a.mod;    // bar()==3
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3a
            static assert(!__traits(compiles, bar()));
            // --> NG, ambiguous: pkg_import3a.bar and pkg_import3a.mod.bar

            assert(pkg_import3a.foo() == 1);        // OK
            assert(pkg_import3a.bar() == 2);        // OK

            assert(pkg_import3a.mod.bar() == 3);    // OK
        }
    }
}
class Test1C
{
    import pkg_import3a.mod;    // bar()==3
    class C
    {
        import pkg_import3a;        // foo()==1, bar()==2
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3a
            assert(bar() == 2);                     // OK, bar in pkg_import3a

            assert(pkg_import3a.foo() == 1);        // OK
            assert(pkg_import3a.bar() == 2);        // OK

            static assert(!__traits(compiles, pkg_import3a.mod.bar()));
            // --> NG, package.d import 'import pkg_import3a' hides FQN 'pkg_import3a.mod'
        }
    }
}

/******************************************/
// Test2 symbol name in pkg_import3b/package.d conflicts with sibling module name which under the pkg_import3b.

class Test2A
{
    import pkg_import3b;        // foo()==1, bar()==2, int mod;
    class C
    {
        import pkg_import3b.mod;    // bar()==3
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3b
            assert(bar() == 3);                     // OK, bar in pkg_import3b.mod

            static assert(!__traits(compiles, pkg_import3b.foo()));
            static assert(!__traits(compiles, pkg_import3b.bar()));
            // --> both NG, inner sub-module import hides outer package.d FQN

            assert(pkg_import3b.mod.bar() == 3);    // OK, bar in pkg_import3b.mod
        }
    }
}
class Test2B
{
    class C
    {
        import pkg_import3b;        // foo()==1, bar()==2, int mod;
        import pkg_import3b.mod;    // bar()==3
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3b
            static assert(!__traits(compiles, bar()));
            // --> NG, ambiguous: pkg_import3b.bar and pkg_import3b.mod.bar

            assert(pkg_import3b.foo() == 1);        // OK
            assert(pkg_import3b.bar() == 2);        // OK

            static assert(!__traits(compiles, pkg_import3b.mod.bar()));
            // --> NG, pkg_import3b.mod is int variable in pkg_import3b/package.d
        }
    }
}
class Test2C
{
    import pkg_import3b.mod;    // bar()==3
    class C
    {
        import pkg_import3b;        // foo()==1, bar()==2, int mod;
        void test()
        {
            assert(foo() == 1);                     // OK, foo in pkg_import3b
            assert(bar() == 2);                     // OK, bar in pkg_import3b

            assert(pkg_import3b.foo() == 1);        // OK
            assert(pkg_import3b.bar() == 2);        // OK

            static assert(!__traits(compiles, pkg_import3b.mod.bar()));
            // --> NG, pkg_import3b.mod is int variable in pkg_import3b/package.d
        }
    }
}

/******************************************/
// from compilable/test7491.d

struct Struct3
{
    import object;
    import imports.imp3a;
    import renamed = imports.imp3b;
}

struct AliasThis3
{
    Struct3 _struct;
    alias _struct this;
}

class Base3
{
    import object;
    import imports.imp3a;
    import renamed = imports.imp3b;
}

class Derived3 : Base3
{
}

interface Interface3
{
    import object;
    import imports.imp3a;
    import renamed = imports.imp3b;
}

class Impl3 : Interface3
{
}

// The package/module names 'object', 'imports', and 'renamed' should not be accessible through type names
static assert(!__traits(compiles, Struct3.object));
static assert(!__traits(compiles, Struct3.imports));
static assert(!__traits(compiles, Struct3.renamed));
static assert(!__traits(compiles, AliasThis3.object));
static assert(!__traits(compiles, AliasThis3.imports));
static assert(!__traits(compiles, AliasThis3.renamed));
static assert(!__traits(compiles, Base3.object));
static assert(!__traits(compiles, Base3.imports));
static assert(!__traits(compiles, Base3.renamed));
static assert(!__traits(compiles, Derived3.object));
static assert(!__traits(compiles, Derived3.imports));
static assert(!__traits(compiles, Derived3.renamed));
static assert(!__traits(compiles, Interface3.object));
static assert(!__traits(compiles, Interface3.imports));
static assert(!__traits(compiles, Interface3.renamed));
static assert(!__traits(compiles, Impl3.object));
static assert(!__traits(compiles, Impl3.imports));
static assert(!__traits(compiles, Impl3.renamed));
