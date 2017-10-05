/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/visitor.d, _visitor.d)
 */

module dmd.visitor;

import dmd.astcodegen;
import dmd.parsetimevisitor;
import dmd.tokens;
import dmd.transitivevisitor;
import dmd.expression;
import dmd.root.rootobject;

// Online documentation: https://dlang.org/phobos/dmd_visitor.html


/** Visitor instantianted with the code generation AST family
 */
alias Visitor = GenericVisitor!ASTCodegen;

// Generic visitor which implements a visit method for all the AST nodes.
private extern (C++) class GenericVisitor(AST) : ParseTimeVisitor!AST
{
    alias visit = ParseTimeVisitor!AST.visit;
public:
    void visit(AST.ErrorStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.PeelStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.UnrolledLoopStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.SwitchErrorStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.DebugStatement s) { visit(cast(AST.Statement)s); }
    void visit(AST.DtorExpStatement s) { visit(cast(AST.ExpStatement)s); }
    void visit(AST.ForwardingStatement s)
    {
        if(s.statement)
            s.statement.accept(this);
    }
    void visit(AST.OverloadSet s) { visit(cast(AST.Dsymbol)s); }
    void visit(AST.LabelDsymbol s) { visit(cast(AST.Dsymbol)s); }
    void visit(AST.WithScopeSymbol s) { visit(cast(AST.ScopeDsymbol)s); }
    void visit(AST.ArrayScopeSymbol s) { visit(cast(AST.ScopeDsymbol)s); }
    void visit(AST.OverDeclaration s) { visit(cast(AST.Declaration)s); }
    void visit(AST.SymbolDeclaration s) { visit(cast(AST.Declaration)s); }
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
    void visit(AST.SymOffExp e) { visit(cast(AST.SymbolExp)e); }
    void visit(AST.OverExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.HaltExp e) { visit(cast(AST.Expression)e); }
    void visit(AST.DotTemplateExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DotVarExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DelegateExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.DotTypeExp e) { visit(cast(AST.UnaExp)e); }
    void visit(AST.VectorExp e) { visit(cast(AST.UnaExp)e); }
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

/** Permissive visitor instantiated with the code generation AST family
 */
alias SemanticTimePermissiveVisitor = GenericPermissiveVisitor!ASTCodegen;

// Generic permissive visitor where all the nodes do nothing
private extern (C++) class GenericPermissiveVisitor(AST) : GenericVisitor!AST
{
    alias visit = GenericVisitor!AST.visit;

    override void visit(AST.Dsymbol){}
    override void visit(AST.Parameter){}
    override void visit(AST.Statement){}
    override void visit(AST.Type){}
    override void visit(AST.Expression){}
    override void visit(AST.TemplateParameter){}
    override void visit(AST.Condition){}
    override void visit(AST.Initializer){}
}

/** Transitive visitor instantiated with the code generation AST family
 */
alias SemanticTimeTransitiveVisitor = GenericTransitiveVisitor!ASTCodegen;

// The generic TransitiveVisitor implements all the AST nodes traversal logic
private extern (C++) class GenericTransitiveVisitor(AST) : GenericPermissiveVisitor!AST
{
    alias visit = GenericPermissiveVisitor!AST.visit;

    mixin ParseVisitMethods!AST;

    override void visit(AST.PeelStatement s)
    {
        if (s.s)
            s.s.accept(this);
    }

    override void visit(AST.UnrolledLoopStatement s)
    {
        foreach(sx; *s.statements)
        {
            if (sx)
                sx.accept(this);
        }
    }

    override void visit(AST.DebugStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(AST.ForwardingStatement s)
    {
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(AST.StructLiteralExp e)
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

    override void visit(AST.DotTemplateExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.DotVarExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.DelegateExp e)
    {
        if (!e.func.isNested())
            e.e1.accept(this);
    }

    override void visit(AST.DotTypeExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.VectorExp e)
    {
        visitType(e.to);
        e.e1.accept(this);
    }

    override void visit(AST.SliceExp e)
    {
        e.e1.accept(this);
        if (e.upr)
            e.upr.accept(this);
        if (e.lwr)
            e.lwr.accept(this);
    }

    override void visit(AST.ArrayLengthExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.DelegatePtrExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.DelegateFuncptrExp e)
    {
        e.e1.accept(this);
    }

    override void visit(AST.DotExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(AST.IndexExp e)
    {
        e.e1.accept(this);
        e.e2.accept(this);
    }

    override void visit(AST.RemoveExp e)
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
