// See ../README.md for information about DMD unit tests.

module frontend;

import support : afterEach, defaultImportPaths;

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("parseModule - custom AST family")
unittest
{
    import std.algorithm : each;

    import dmd.astcodegen : ASTCodegen;
    import dmd.dclass : ClassDeclaration;
    import dmd.frontend;
    import dmd.visitor : SemanticTimeTransitiveVisitor;

    static struct AST
    {
        ASTCodegen ast;
        alias ast this;

        extern (C++) static final class InterfaceDeclaration : ClassDeclaration
        {
            import dmd.arraytypes : BaseClasses;
            import dmd.identifier : Identifier;
            import dmd.location;

            bool created = false;

            extern (D) this(const ref Loc loc, Identifier id, BaseClasses* baseclasses)
            {
                super(loc, id, baseclasses, null, false);
                created = true;
            }
        }
    }

    extern (C++) static class Visitor : SemanticTimeTransitiveVisitor
    {
        alias visit = typeof(super).visit;

        bool created = false;

        override void visit(ClassDeclaration cdecl)
        {
            created = (cast(AST.InterfaceDeclaration) cdecl).created;
        }
    }

    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule!AST("frontendcustomASTfamily.d", q{
        interface Foo {}
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.created);
}

@("parseModule - invalid module name")
unittest
{
    import dmd.frontend;

    initDMD();

    auto t = parseModule("foo/bar.d", "");

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    const actual = t.module_.ident.toString;
    assert(actual == "bar", actual);
}

@("parseModule - missing package")
unittest
{
    import dmd.frontend;

    initDMD();

    auto t = parseModule("foo/bar.d", q{
        module foo.bar;
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    assert(t.module_.parent !is null);
}

@("parseModule - invalid module")
unittest
{
    import std.conv : to;
    import dmd.frontend;

    import dmd.common.outbuffer;
    import dmd.console : Color;
    import dmd.location;
    import core.stdc.stdarg : va_list;

    string[] diagnosticMessages;

    nothrow bool diagnosticHandler(const ref Loc loc, Color headerColor, const(char)* header,
                                   const(char)* format, va_list ap, const(char)* p1, const(char)* p2)
    {
        OutBuffer tmp;
        tmp.vprintf(format, ap);
        diagnosticMessages ~= to!string(tmp.peekChars());
        return true;
    }
    initDMD(&diagnosticHandler);

    auto bom = parseModule("foo/bar.d", [0x84, 0xC3]);
    assert(bom.diagnostics.hasErrors);
    assert(bom.module_ is null);

    auto odd16 = parseModule("foo/bar.d", [0xFE, 0xFF, 0x84, 0x00]);
    assert(odd16.diagnostics.hasErrors);
    assert(odd16.module_ is null);

    auto odd32 = parseModule("foo/bar.d", [0x00, 0x00, 0xFE, 0xFF, 0x84, 0x81]);
    assert(odd32.diagnostics.hasErrors);
    assert(odd32.module_ is null);

    auto utf32gt = parseModule("foo/bar.d", [0x00, 0x00, 0xFE, 0xFF, 0x84, 0x81, 0x00]);
    assert(utf32gt.diagnostics.hasErrors);
    assert(utf32gt.module_ is null);

    auto ill16 = parseModule("foo/bar.d", [0xFE, 0xFF, 0xFF, 0xFF, 0x00]);
    assert(ill16.diagnostics.hasErrors);
    assert(ill16.module_ is null);

    auto unp16 = parseModule("foo/bar.d", [0xFE, 0xFF, 0xDC, 0x00, 0x00]);
    assert(unp16.diagnostics.hasErrors);
    assert(unp16.module_ is null);

    auto sur16 = parseModule("foo/bar.d", [0xFE, 0xFF, 0xD8, 0x00, 0xE0, 0x00, 0x00]);
    assert(sur16.diagnostics.hasErrors);
    assert(sur16.module_ is null);

    assert(diagnosticMessages.length == 7);
    assert(endsWith(diagnosticMessages[0], "source file must start with BOM or ASCII character, not \\x84"));
    assert(endsWith(diagnosticMessages[1], "odd length of UTF-16 char source 3"));
    assert(endsWith(diagnosticMessages[2], "odd length of UTF-32 char source 3"));
    assert(endsWith(diagnosticMessages[3], "UTF-32 value 84810000 greater than 0x10FFFF"));
    assert(endsWith(diagnosticMessages[4], "illegal UTF-16 value ffff"));
    assert(endsWith(diagnosticMessages[5], "unpaired surrogate UTF-16 value dc00"));
    assert(endsWith(diagnosticMessages[6], "surrogate UTF-16 low value e000 out of range"));
}

@("initDMD - contract checking")
unittest
{
    import std.algorithm : each;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule("frontendcontractchecking.d", q{
        int foo(int a)
        in(a == 3)
        out(result; result == 0)
        {
            if (a == 1)
                assert(false);

            int[] array;
            array[0] = 3;

            final switch (3)
            {
                case 4: break;
            }

            return 0;
        }

        class Foo
        {
            int a;
            invariant(a > 0);
        }
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 0);
}

@("initDMD - version identifiers")
unittest
{
    import std.algorithm : each;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD(null, null, ["Foo"]);
    defaultImportPaths.each!addImport;

    auto t = parseModule("frontendversionidentifiers.d", q{
        version (Foo)
            enum a = 1;
        else
            enum a = 2;

        static assert(a == 1);
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 0);
}

@("initDMD - custom diagnostic handling")
unittest
{
    import std.conv;
    import std.algorithm : each;

    import core.stdc.stdarg : va_list;

    import dmd.frontend;
    import dmd.common.outbuffer;
    import dmd.console : Color;
    import dmd.location;

    string[] diagnosticMessages;

    nothrow bool diagnosticHandler(const ref Loc loc, Color headerColor, const(char)* header,
                                   const(char)* format, va_list ap, const(char)* p1, const(char)* p2)
    {
        OutBuffer tmp;
        tmp.vprintf(format, ap);
        diagnosticMessages ~= to!string(tmp.peekChars());
        return true;
    }

    initDMD(&diagnosticHandler);
    defaultImportPaths.each!addImport;

    parseModule("frontendcustomdiagnostichandling.d", q{
        void foo(){
            auto temp == 7.8;
            foreach(i; 0..5){
            }
        }
    });

    assert(endsWith(diagnosticMessages[0], "no identifier for declarator `temp`"));
    assert(endsWith(diagnosticMessages[1], "found `==` instead of statement"));
}

@("addStringImport") unittest
{
    import std.algorithm : each;
    import std.path : dirName, buildPath;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD();
    defaultImportPaths.each!addImport;
    addStringImport(__FILE_FULL_PATH__.dirName.buildPath("support", "data"));

    auto t = parseModule("frontendaddStringImport.d", q{
        enum a = import("foo.txt");
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 0);
}

@("initDMD - floating-point")
unittest
{
    import std.algorithm : each;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule("frontendfloatingpoint.d", q{
        static assert((2.0i).re == 0);
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 0);
}

@("inline assembly")
unittest
{
    import std.algorithm : each;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule("frontendinlineassembly.d", q{
        void foo()
        {
            asm
            {
                call foo;
            }
        }
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 0);
}

// Issue https://issues.dlang.org/show_bug.cgi?id=22906
@("semantics on non regular module")
unittest
{
    import std.algorithm : each;
    import std.conv : to;

    import core.stdc.stdarg : va_list;

    import dmd.frontend;
    import dmd.globals : global;
    import dmd.common.outbuffer;
    import dmd.console : Color;
    import dmd.location;

    string[] diagnosticMessages;

    nothrow bool diagnosticHandler(const ref Loc loc, Color headerColor, const(char)* header,
                                   const(char)* format, va_list ap, const(char)* p1, const(char)* p2)
    {
        OutBuffer tmp;
        tmp.vprintf(format, ap);
        diagnosticMessages ~= to!string(tmp.peekChars());
        return true;
    }

    initDMD(&diagnosticHandler);
    defaultImportPaths.each!addImport;

    auto t = parseModule("frontendddoc.dd", q{Ddoc});

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic();

    assert(global.errors == 1);
    assert(endsWith(diagnosticMessages[0], "is a Ddoc file, cannot import it"));
}

bool endsWith(string diag, string msg)
{
    return diag.length >= msg.length && diag[$ - msg.length .. $] == msg;
}
