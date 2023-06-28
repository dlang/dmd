// See ../../README.md for information about DMD unit tests.

/**
 * Test cases for issue [20861][1].
 *
 * It's intended to verify that a class implements all the methods of all
 * interfaces it implements, even though code generation is not performed.
 *
 * Also https://github.com/ldc-developers/ldc/issues/3302.
 *
 * [1]: https://issues.dlang.org/show_bug.cgi?id=20861
 */
module interfaces.check_implementations_20861;

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

@("when an interface method is not implemented")
{
    @("it should report an error")
    unittest
    {
        enum filename = "test.d";

        enum code = q{
            interface Foo
            {
                void foo();
            }

            class Bar : Foo { }
        }.stripDelimited;

        enum message = "Error: class test.Bar interface function void foo() is not implemented";
        const expected = Diagnostic(Loc(filename, 6, 1), message);

        const diagnostics = compiles(code, filename);
        assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
    }

    @("when an interface method is included as a string mixin")
    @("it should report an error")
    unittest
    {
        enum filename = "test.d";

        enum code = q{
            interface Foo
            {
                mixin("void foo();");
            }

            class Bar : Foo { }
        }.stripDelimited;

        enum message = "Error: class test.Bar interface function void foo() is not implemented";
        const expected = Diagnostic(Loc(filename, 6, 1), message);

        const diagnostics = compiles(code, filename);
        assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
    }

    @("when an interface method is included as a template mixin")
    @("it should report an error")
    unittest
    {
        enum filename = "test.d";

        enum code = q{
            template Baz()
            {
                void foo();
            }

            interface Foo
            {
                mixin Baz;
            }

            class Bar : Foo { }
        }.stripDelimited;

        enum message = "Error: class test.Bar interface function void foo() is not implemented";
        const expected = Diagnostic(Loc(filename, 11, 1), message);

        const diagnostics = compiles(code, filename);
        assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
    }

    @("when an interface is not reimplemented")
    @("it should report an error")
    unittest
    {
        enum filename = "test.d";

        enum code = q{
            interface D
            {
                void foo();
            }

            class A : D
            {
                void foo() {}
            }

            class B : A, D
            {
            }
        }.stripDelimited;

        enum message = "Error: class test.B interface function void foo() is not implemented";
        const expected = Diagnostic(Loc(filename, 11, 1), message);

        const diagnostics = compiles(code, filename);
        assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
    }
}

@("when all interface methods are implemented")
{
    @("it should compile")
    unittest
    {
        enum code = q{
            interface Foo
            {
                void foo();
            }

            class Bar : Foo
            {
                void foo() {}
            }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, "\n" ~ result.toString);
    }

    @("when a method is implemented using a string mixin")
    @("it should compile")
    unittest
    {
        enum code = q{
            interface Foo
            {
                void foo();
            }

            class Bar : Foo
            {
                mixin("void foo() {}");
            }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, "\n" ~ result.toString);
    }

    @("when a method is implemented using a template mixin")
    @("it should compile")
    unittest
    {
        enum code = q{
            interface Foo
            {
                void foo();
            }

            template Baz()
            {
                void foo() {}
            }

            class Bar : Foo
            {
                mixin Baz;
            }
        }.stripDelimited;

        const result = compiles(code);
        assert(result, "\n" ~ result.toString);
    }
}
