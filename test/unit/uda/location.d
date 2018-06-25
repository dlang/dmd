module uda.location;

import dmd.lexer : DiagnosticReporter;

import support : afterEach, beforeEach;

// The code snippets in these tests are deliberately formatted to have the UDA
// on its own line. This will ensure that the location of the UDA is of the UDA
// AST node and no other AST node.

@beforeEach initializeFrontend()
{
    import std.algorithm : each;
    import dmd.frontend : addImport, initDMD;
    import support : defaultImportPaths;

    initDMD();
    defaultImportPaths.each!addImport;
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("module declaration: @(3) module m")
unittest
{
    import dmd.frontend : parseModule;

    const t = parseModule("test.d", q{
        @(3)
        module m;
    });

    assert(t.module_.userAttribDecl.loc.linnum == 2);
}

@("variable declaration with inferred type: @(3) a = 3")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        @(3)
        a = 3;
    });

    assert(lineNumber == 2);
}

@("function declaration: @(3) auto foo () { return 3; }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        @(3)
        auto foo () { return 3; }
    });

    assert(lineNumber == 2);
}

@("aggregate declaration: @(3) struct foo {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        @(3)
        struct foo {}
    });

    assert(lineNumber == 2);
}

@("variable declaration with old UDA syntax: [3] int a = 3")
unittest
{
    // The square brackets, `[3]`, syntax for UDAs is the old syntax, before the
    // `@(3)` syntax was used. This results in a compile error, but it's still
    // recognized by the parser and the parser creates an AST node for the UDA.
    // Therefore we suppress the error message below to avoid having it printed
    // when running the test.

    import support : NoopDiagnosticReporter;

    const lineNumber = extractUDALineNumber(q{
        [3]
        int a = 3;
    }, new NoopDiagnosticReporter);

    assert(lineNumber == 2);
}

@("postblit with postfix UDA: this(this) @(3) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        struct Foo
        {
            this(this)
            @(3)
            {}
        }
    });

    assert(lineNumber == 5);
}

@("constructor with postfix UDA: this() @(3) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        class Foo
        {
            this()
            @(3)
            {}
        }
    });

    assert(lineNumber == 5);
}

@("destructor with postfix UDA: ~this() @(3) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        struct Foo
        {
            ~this()
            @(3)
            {}
        }
    });

    assert(lineNumber == 5);
}

@("static destructor with postfix UDA: static ~this() @(3) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        static ~this()
        @(3)
        {}
    });

    assert(lineNumber == 3);
}

@("shared static destructor with postfix UDA: shared static ~this() @(3) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        shared static ~this()
        @(3)
        {}
    });

    assert(lineNumber == 3);
}

@("nested aggregate: void foo() { @(3) struct Bar {} }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo()
        {
            @(3)
            struct Bar {}
        }
    });

    assert(lineNumber == 4);
}

@("nested variable declaration with inferred type: void foo() { @(3) a = 3; }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo()
        {
            @(3)
            a = 3;
        }
    });

    assert(lineNumber == 4);
}

@("function with postfix UDA: void foo() @(4) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo()
        @(4)
        {}
    });

    assert(lineNumber == 3);
}

@("nested variable declaration: void foo() { @(3) int a = 4; }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo()
        {
            @(3)
            int a = 4;
        }
    });

    assert(lineNumber == 4);
}

@("parameter: void foo(@(3) int a) {}")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo(
            @(3)
            int a) {}
    });

    assert(lineNumber == 3);
}

@("enum member: enum { @(3) a }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        enum
        {
            @(3)
            a
        }
    });

    assert(lineNumber == 4);
}

@("parameter with inferred type: alias a = @(3) b => 4")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        alias a =
        @(3)
        b => 4;
    });

    assert(lineNumber == 3);
}

@("nested enum: void foo() { @(3) enum a { b } }")
unittest
{
    const lineNumber = extractUDALineNumber(q{
        void foo()
        {
            @(3)
            enum a { b }
        }
    });

    assert(lineNumber == 4);
}

private int extractUDALineNumber(string code,
    DiagnosticReporter diagnosticReporter = null)
{
    import dmd.attrib : UserAttributeDeclaration;
    import dmd.frontend : parseModule;
    import dmd.globals : global;
    import dmd.lexer : StderrDiagnosticReporter;
    import dmd.visitor : SemanticTimeTransitiveVisitor;

    if (!diagnosticReporter)
        diagnosticReporter = new StderrDiagnosticReporter(global.params.useDeprecated);

    auto t = parseModule("test.d", code, diagnosticReporter);

    extern (C++) static class Visitor : SemanticTimeTransitiveVisitor
    {
        alias visit = typeof(super).visit;
        int lineNumber = -1;

        override void visit(UserAttributeDeclaration uda)
        {
            lineNumber = uda.loc.linnum;
        }
    }

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    return visitor.lineNumber;
}
