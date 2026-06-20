module semantic.inline;

import std.algorithm : each;

import dmd.astenums : PINLINE;
import dmd.frontend;
import dmd.func : FuncDeclaration;
import dmd.visitor : SemanticTimeTransitiveVisitor;

import support : afterEach, beforeEach, defaultImportPaths;

@beforeEach void initializeFrontend()
{
    initDMD();
}

@afterEach void deinitializeFrontend()
{
    deinitializeDMD();
}

@("semantics - inline pragma does not leak into nested functions")
unittest
{
    extern (C++) static final class Visitor : SemanticTimeTransitiveVisitor
    {
        alias visit = typeof(super).visit;

        FuncDeclaration test2;
        FuncDeclaration test2Abc;
        FuncDeclaration test3Abc;

        override void visit(FuncDeclaration fd)
        {
            auto parent = fd.toParent().isFuncDeclaration();
            if (fd.ident && fd.ident.toString() == "test2" && !parent)
                test2 = fd;
            else if (fd.ident && fd.ident.toString() == "abc" && parent && parent.ident)
            {
                if (parent.ident.toString() == "test2")
                    test2Abc = fd;
                else if (parent.ident.toString() == "test3")
                    test3Abc = fd;
            }

            super.visit(fd);
        }
    }

    defaultImportPaths.each!addImport;

    auto result = parseModule("test20375.d", q{
        pragma(inline, true)
        void test2()
        {
            static int abc(int a) { return a; }
            abc(5);
        }

        void test3()
        {
            pragma(inline, true) static int abc(int a) { return a; }
            abc(5);
        }
    });

    assert(!result.diagnostics.hasErrors);
    assert(!result.diagnostics.hasWarnings);

    result.module_.fullSemantic();

    scope visitor = new Visitor;
    result.module_.accept(visitor);

    assert(visitor.test2 !is null);
    assert(visitor.test2Abc !is null);
    assert(visitor.test3Abc !is null);
    assert(visitor.test2.inlining == PINLINE.always);
    assert(visitor.test2Abc.inlining == PINLINE.default_);
    assert(visitor.test3Abc.inlining == PINLINE.always);
}
