// See ../../../README.md for information about DMD unit tests.

/// Test cases for diagnostic messages on Objective-C protocols
module objc.protocols.diagnostic_messages;

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

@("when a static interface method is not implemented")
@("it should report an error")
@("the error message should include that the method is a static method")
@("the error message should _not_ include the name of the metaclass")
unittest
{
    enum filename = "test.d";

    enum code = q{
        extern (Objective-C)
        interface Foo
        {
            static void foo();
        }

        extern (Objective-C)
        class Bar : Foo { }
    }.stripDelimited;

    enum message = "Error: class test.Bar interface function extern (Objective-C) static void foo() is not implemented";
    auto expected = Diagnostic(Loc(filename, 8, 1), message);

    const diagnostics = compiles(code, filename);
    assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
}

@("when a static interface method has a body")
@("it should report an error")
unittest
{
    enum filename = "test.d";

    enum code = q{
        extern (Objective-C)
        interface Foo
        {
            static void foo() { }
        }

        extern (Objective-C)
        class Bar : Foo { }
    }.stripDelimited;

    enum message = "Error: function test.Foo.foo function body only allowed in final functions in interface Foo";
    auto expected = Diagnostic(Loc(filename, 4, 17), message);

    const diagnostics = compiles(code, filename);
    assert(diagnostics == [expected], "\n" ~ diagnostics.toString);
}
