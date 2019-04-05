module frontend;

import support : afterEach, beforeEach, defaultImportPaths;

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
