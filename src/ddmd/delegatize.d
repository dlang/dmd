/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _delegatize.d)
 */

module ddmd.delegatize;

import core.stdc.stdio;
import ddmd.apply;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.initsem;
import ddmd.mtype;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;

extern (C++) Expression toDelegate(Expression e, Type t, Scope* sc)
{
    //printf("Expression::toDelegate(t = %s) %s\n", t.toChars(), e.toChars());
    Loc loc = e.loc;
    auto tf = new TypeFunction(null, t, 0, LINKd);
    if (t.hasWild())
        tf.mod = MODwild;
    auto fld = new FuncLiteralDeclaration(loc, loc, tf, TOKdelegate, null);
    sc = sc.push();
    sc.parent = fld; // set current function to be the delegate
    lambdaSetParent(e, sc);
    bool r = lambdaCheckForNestedRef(e, sc);
    sc = sc.pop();
    if (r)
        return new ErrorExp();
    Statement s;
    if (t.ty == Tvoid)
        s = new ExpStatement(loc, e);
    else
        s = new ReturnStatement(loc, e);
    fld.fbody = s;
    e = new FuncExp(loc, fld);
    e = e.semantic(sc);
    return e;
}

/******************************************
 * Patch the parent of declarations to be the new function literal.
 */
extern (C++) void lambdaSetParent(Expression e, Scope* sc)
{
    extern (C++) final class LambdaSetParent : StoppableVisitor
    {
        alias visit = super.visit;
        Scope* sc;

    public:
        extern (D) this(Scope* sc)
        {
            this.sc = sc;
        }

        override void visit(Expression)
        {
        }

        override void visit(DeclarationExp e)
        {
            e.declaration.parent = sc.parent;
        }

        override void visit(IndexExp e)
        {
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                e.lengthVar.parent = sc.parent;
            }
        }

        override void visit(SliceExp e)
        {
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                e.lengthVar.parent = sc.parent;
            }
        }
    }

    scope LambdaSetParent lsp = new LambdaSetParent(sc);
    walkPostorder(e, lsp);
}

/*******************************************
 * Look for references to variables in a scope enclosing the new function literal.
 * Returns true if error occurs.
 */
extern (C++) bool lambdaCheckForNestedRef(Expression e, Scope* sc)
{
    extern (C++) final class LambdaCheckForNestedRef : StoppableVisitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        bool result;

        extern (D) this(Scope* sc)
        {
            this.sc = sc;
        }

        override void visit(Expression)
        {
        }

        override void visit(SymOffExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
                result = v.checkNestedReference(sc, Loc());
        }

        override void visit(VarExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
                result = v.checkNestedReference(sc, Loc());
        }

        override void visit(ThisExp e)
        {
            if (e.var)
                result = e.var.checkNestedReference(sc, Loc());
        }

        override void visit(DeclarationExp e)
        {
            VarDeclaration v = e.declaration.isVarDeclaration();
            if (v)
            {
                result = v.checkNestedReference(sc, Loc());
                if (result)
                    return;
                /* Some expressions cause the frontend to create a temporary.
                 * For example, structs with cpctors replace the original
                 * expression e with:
                 *  __cpcttmp = __cpcttmp.cpctor(e);
                 *
                 * In this instance, we need to ensure that the original
                 * expression e does not have any nested references by
                 * checking the declaration initializer too.
                 */
                if (v._init && v._init.isExpInitializer())
                {
                    Expression ie = v._init.initializerToExpression();
                    result = lambdaCheckForNestedRef(ie, sc);
                }
            }
        }
    }

    scope LambdaCheckForNestedRef v = new LambdaCheckForNestedRef(sc);
    walkPostorder(e, v);
    return v.result;
}

/*****************************************
 * See if context `s` is nested within context `p`, meaning
 * it `p` is reachable at runtime by walking the static links.
 * If any of the intervening contexts are function literals,
 * make sure they are delegates.
 * Params:
 *      s = inner context
 *      p = outer context
 * Returns:
 *      true means it is accessible by walking the context pointers at runtime
 * References:
 *      for static links see https://en.wikipedia.org/wiki/Call_stack#Functions_of_the_call_stack
 */
bool ensureStaticLinkTo(Dsymbol s, Dsymbol p)
{
    while (s)
    {
        if (s == p) // hit!
            return true;

        if (auto fd = s.isFuncDeclaration())
        {
            if (!fd.isThis() && !fd.isNested())
                break;

            // https://issues.dlang.org/show_bug.cgi?id=15332
            // change to delegate if fd is actually nested.
            if (auto fld = fd.isFuncLiteralDeclaration())
                fld.tok = TOKdelegate;
        }
        if (auto ad = s.isAggregateDeclaration())
        {
            if (ad.storage_class & STCstatic)
                break;
        }
        s = s.toParent2();
    }
    return false;
}
