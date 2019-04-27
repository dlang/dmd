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
            import dmd.globals : Loc;
            import dmd.identifier : Identifier;

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

    auto t = parseModule!AST("test.d", q{
        interface Foo {}
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    scope visitor = new Visitor;
    t.module_.accept(visitor);

    assert(visitor.created);
}

@("initDMD - contract checking")
unittest
{
    import std.algorithm : each;

    import dmd.frontend;
    import dmd.globals : global;

    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule("test.d", q{
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

    initDMD(["Foo"]);
    defaultImportPaths.each!addImport;

    auto t = parseModule("test.d", q{
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
