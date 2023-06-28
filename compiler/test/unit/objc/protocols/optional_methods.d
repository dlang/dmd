// See ../../../README.md for information about DMD unit tests.

/// Test cases for diagnostic messages on Objective-C protocols
module objc.protocols.optional_methods;

version (D_ObjectiveC):

import dmd.location;

import support : afterEach, beforeEach, compiles, stripDelimited, Diagnostic;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("when an optional method is not implemented")
{
    @("when the method is an instance method")
    @("it should successfully compile")
    unittest
    {
        enum code = q{
            import core.attribute : optional;

            extern (Objective-C)
            interface Foo
            {
                @optional void foo();
            }

            extern (Objective-C)
            class Bar : Foo { }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, '\n' ~ result.toString);
    }

    @("when the method is a static method")
    @("it should successfully compile")
    unittest
    {
        enum filename = "test.d";

        enum code = q{
            import core.attribute : optional;

            extern (Objective-C)
            interface Foo
            {
                @optional static void foo();
            }

            extern (Objective-C)
            class Bar : Foo { }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, '\n' ~ result.toString);
    }

    @("when the `@optional:` syntax is used")
    @("it should successfully compile")
    unittest
    {
        enum code = q{
            import core.attribute : optional;

            extern (Objective-C)
            interface Foo
            {
            @optional:
                void foo();
            }

            extern (Objective-C)
            class Bar : Foo { }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, '\n' ~ result.toString);
    }

    @("when the `@optional {}` syntax is used")
    @("it should successfully compile")
    unittest
    {
        enum code = q{
            import core.attribute : optional;

            extern (Objective-C)
            interface Foo
            {
                @optional
                {
                    void foo();
                }
            }

            extern (Objective-C)
            class Bar : Foo { }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, '\n' ~ result.toString);
    }
}

@("when attaching `@optional` to method that doesn't have Objective-C linkage")
@("it should report an error")
unittest
{
    enum filename = "test.d";

    enum code = q{
        import core.attribute : optional;

        interface Foo
        {
            @optional void foo();
        }
    }.stripDelimited;

    Loc loc = Loc(filename, 5, 20);
    enum message = "Error: function test.Foo.foo only functions with Objective-C linkage can be declared as optional";
    enum supplemental = "function is declared with D linkage";
    auto expected = [Diagnostic(loc, message), Diagnostic(loc, supplemental)];

    const diagnostics = compiles(code, filename);
    assert(diagnostics == expected, "\n" ~ diagnostics.toString);
}

@("when attaching `@optional` more than once to the same method")
@("it should report an error")
unittest
{
    enum filename = "test.d";

    enum code = q{
        import core.attribute : optional;

        extern (Objective-C)
        interface Foo
        {
            @optional @optional void foo();
        }
    }.stripDelimited;

    Loc loc = Loc(filename, 6, 30);
    enum message = "Error: function test.Foo.foo can only declare a function as optional once";
    auto expected = Diagnostic(loc, message);

    const diagnostics = compiles(code, filename);
    assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
}

@("when attaching `@optional` to a template method")
@("it should report an error")
unittest
{
    enum filename = "test.d";

    enum code = q{
        import core.attribute : optional;

        extern (Objective-C)
        interface Foo
        {
            @optional void foo()();
        }

        void main()
        {
            Foo f;
            f.foo();
        }
    }.stripDelimited;

    Loc loc = Loc(filename, 6, 20);

    auto expected = [
        Diagnostic(
            Loc(filename, 6, 20),
            "Error: function test.Foo.foo!().foo template cannot be optional"
        ),
        Diagnostic(
            Loc(filename, 12, 10),
            "Error: template instance test.Foo.foo!() error instantiating"
        )
    ];

    const diagnostics = compiles(code, filename);
    assert(diagnostics == expected, "\n" ~ diagnostics.toString);
}

@("when attaching `@optional` to a method _not_ declared in an interface")
@("it should report an error")
unittest
{
    enum filename = "test.d";

    enum code = q{
        import core.attribute : optional;

        extern (Objective-C)
        class Foo
        {
            @optional void foo() {};
        }

        void main()
        {
            Foo f;
            f.foo();
        }
    }.stripDelimited;

    Loc loc = Loc(filename, 6, 20);
    enum message = "Error: function test.Foo.foo only functions declared inside interfaces can be optional";
    enum supplemental = "function is declared inside class";
    auto expected = [Diagnostic(loc, message), Diagnostic(loc, supplemental)];

    const diagnostics = compiles(code, filename);
    assert(diagnostics == expected, "\n" ~ diagnostics.toString);
}
