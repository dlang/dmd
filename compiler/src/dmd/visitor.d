/**
 * Provides a visitor class visiting all AST nodes present in the compiler.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/visitor.d, _visitor.d)
 * Documentation:  https://dlang.org/phobos/dmd_visitor.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/visitor.d
 */

module dmd.visitor;

import dmd.astcodegen;
import dmd.astenums;
import dmd.parsetimevisitor;
import dmd.tokens;
import dmd.transitivevisitor;
import dmd.expression;
import dmd.root.rootobject;

/**
 * Classic Visitor class which implements visit methods for all the AST
 * nodes present in the compiler. The visit methods for AST nodes
 * created at parse time are inherited while the visiting methods
 * for AST nodes created at semantic time are implemented.
 */
extern (C++) class VisitorTemplate(AST) : ParseTimeVisitor!AST
{
    alias visit = ParseTimeVisitor!AST.visit;
public:
    void visit(AST.ErrorStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.PeelStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.UnrolledLoopStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.SwitchErrorStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.DebugStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.DtorExpStatement s) { visit(cast(AST.ExpStatement)s); }
    void visit(AST.ForwardingStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.OverloadSet s) { visit(cast(AST.Dsymbol)s); }
    void visit(AST.LabelDsymbol s) { visit(cast(AST.Dsymbol)s); }
    void visit(AST.WithScopeSymbol s) { visit(cast(AST.ScopeDsymbol)s); }
    void visit(AST.ArrayScopeSymbol s) { visit(cast(AST.ScopeDsymbol)s); }
    void visit(AST.OverDeclaration s) { visit(cast(AST.Declaration)s); }
    void visit(AST.SymbolDeclaration s) { visit(cast(AST.Declaration)s); }
    void visit(AST.ForwardingAttribDeclaration s) { visit(cast(AST.AttribDeclaration)s); }
    void visit(AST.ThisDeclaration s) { visit(cast(AST.VarDeclaration)s); }
    void visit(AST.TypeInfoDeclaration s) { visit(cast(AST.VarDeclaration)s); }
    void visit(AST.TypeInfoStructDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoClassDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoInterfaceDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoPointerDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoArrayDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoStaticArrayDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoAssociativeArrayDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoEnumDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoFunctionDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoDelegateDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoTupleDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoConstDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoInvariantDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoSharedDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoWildDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.TypeInfoVectorDeclaration s) { visit(cast(AST.TypeInfoDeclaration)s); }
    void visit(AST.FuncAliasDeclaration s) { visit(cast(AST.FuncDeclaration)s); }
    void visit(AST.ErrorInitializer i) { visit(cast(AST.Initializer)i); }
    void visit(AST.ErrorExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.ComplexExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.StructLiteralExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.CompoundLiteralExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.ObjcClassReferenceExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.SymOffExp e) { visit(cast(AST.SymbolExp)e); }
    void visit(AST.OverExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.HaltExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.DotTemplateExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DotVarExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DelegateExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DotTypeExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.VectorExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.VectorArrayExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.SliceExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.ArrayLengthExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DelegatePtrExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DelegateFuncptrExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DotExp e) { visit(cast(AST.BinExp)e); }
    void visit(AST.IndexExp e) { visit(cast(AST.BinExp)e); }
    void visit(AST.ConstructExp e) { visit(cast(AST.AssignExp)e); }
    void visit(AST.BlitExp e) { visit(cast(AST.AssignExp)e); }
    void visit(AST.RemoveExp e) { visit(cast(AST.BinExp)e); }
    void visit(AST.ClassReferenceExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.VoidInitExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.ThrownExceptionExp e) { visit(cast(AST.Expression)e); }
}

/**
 * Classic Visitor using ASTCodegen family
 */
extern (C++) class Visitor : VisitorTemplate!ASTCodegen
{

}

/**
 * The PermissiveVisitor overrides the root AST nodes with
 * empty visiting methods.
 */
extern (C++) class SemanticTimePermissiveVisitor : Visitor
{
    alias visit = Visitor.visit;

    override void visit(ASTCodegen.Dsymbol){}
    override void visit(ASTCodegen.Parameter){}
    override void visit(ASTCodegen.Statement){}
    override void visit(ASTCodegen.Type){}
    override void visit(ASTCodegen.Expression){}
    override void visit(ASTCodegen.TemplateParameter){}
    override void visit(ASTCodegen.Condition){}
    override void visit(ASTCodegen.Initializer){}
}

/**
 * The TransitiveVisitor implements the AST traversal logic for all AST nodes.
 */
extern (C++) class SemanticTimeTransitiveVisitor : SemanticTimePermissiveVisitor
{
    alias visit = SemanticTimePermissiveVisitor.visit;

    mixin ParseVisitMethods!ASTCodegen __methods;
    alias visit = __methods.visit;

    override void visit(ASTCodegen.PeelStatement s)
    {
        if (s.s)
            s.s.accept(this);
    }

    override void visit(ASTCodegen.UnrolledLoopStatement s)
    {
        foreach(sx; *s.statements)
        {
            if (sx)
                sx.accept(this);
        }
    }

    override void visit(ASTCodegen.DebugStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(ASTCodegen.ForwardingStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(ASTCodegen.StructLiteralExp e)
    {
        // CTFE can generate struct literals that contain an AddrExp pointing to themselves,
        // need to avoid infinite recursion.
        if (!(e.stageflags & stageToCBuffer))
        {
            int old = e.stageflags;
            e.stageflags |= stageToCBuffer;
            foreach (el; *e.elements)
                if (el)
                    el.accept(this);
            e.stageflags = old;
        }
    }

    override void visit(ASTCodegen.CompoundLiteralExp e)
    {
        if (e.initializer)
            e.initializer.accept(this);
    }

    override void visit(ASTCodegen.DotTemplateExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.DotVarExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.DelegateExp e)
    {
        if (!e.func.isNested() || e.func.needThis())
            e.e1.accept(this);
    }

    override void visit(ASTCodegen.DotTypeExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.VectorExp e)
    {
        visitType(e.to);
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.VectorArrayExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.SliceExp e)
    {
        e.e1.accept(this);
        if (e.upr)
            e.upr.accept(this);
        if (e.lwr)
            e.lwr.accept(this);
    }

    override void visit(ASTCodegen.ArrayLengthExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.DelegatePtrExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.DelegateFuncptrExp e)
    {
        e.e1.accept(this);
    }

    override void visit(ASTCodegen.DotExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(ASTCodegen.IndexExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(ASTCodegen.RemoveExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }
}

extern (C++) class StoppableVisitor : Visitor
{
    alias visit = Visitor.visit;
public:
    bool stop;

    final extern (D) this()
    {
    }
}
