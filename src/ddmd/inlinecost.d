/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC _inlinecost.d)
 */

module ddmd.inlinecost;

import core.stdc.stdio;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.apply;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.mtype;
import ddmd.opover;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;

enum COST_MAX = 250;

private enum STATEMENT_COST = 0x1000;
private enum STATEMENT_COST_MAX = 250 * STATEMENT_COST;

// STATEMENT_COST be power of 2 and greater than COST_MAX
static assert((STATEMENT_COST & (STATEMENT_COST - 1)) == 0);
static assert(STATEMENT_COST > COST_MAX);

/*********************************
 * Determine if too expensive to inline.
 * Params:
 *      cost = cost of inlining
 * Returns:
 *      true if too costly
 */
bool tooCostly(int cost) pure nothrow
{
    return ((cost & (STATEMENT_COST - 1)) >= COST_MAX);
}

/*********************************
 * Determine cost of inlining Expression
 * Params:
 *      e = Expression to determine cost of
 * Returns:
 *      cost of inlining e
 */
int inlineCostExpression(Expression e)
{
    scope InlineCostVisitor icv = new InlineCostVisitor(false, true, true, null);
    icv.expressionInlineCost(e);
    return icv.cost;
}


/*********************************
 * Determine cost of inlining function
 * Params:
 *      fd = function to determine cost of
 * Returns:
 *      cost of inlining fd
 */
int inlineCostFunction(FuncDeclaration fd, bool hasthis, bool hdrscan)
{
    scope InlineCostVisitor icv = new InlineCostVisitor(hasthis, hdrscan, false, fd);
    fd.fbody.accept(icv);
    return icv.cost;
}

private:

/***********************************************************
 * Compute cost of inlining.
 *
 * Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */
extern (C++) final class InlineCostVisitor : Visitor
{
    alias visit = super.visit;
public:
    int nested;
    bool hasthis;
    bool hdrscan;       // if inline scan for 'header' content
    bool allowAlloca;
    FuncDeclaration fd;
    int cost;           // zero start for subsequent AST

    extern (D) this()
    {
    }

    extern (D) this(bool hasthis, bool hdrscan, bool allowAlloca, FuncDeclaration fd)
    {
        this.hasthis = hasthis;
        this.hdrscan = hdrscan;
        this.allowAlloca = allowAlloca;
        this.fd = fd;
    }

    extern (D) this(InlineCostVisitor icv)
    {
        nested = icv.nested;
        hasthis = icv.hasthis;
        hdrscan = icv.hdrscan;
        allowAlloca = icv.allowAlloca;
        fd = icv.fd;
    }

    override void visit(Statement s)
    {
        //printf("Statement.inlineCost = %d\n", COST_MAX);
        //printf("%p\n", s.isScopeStatement());
        //printf("%s\n", s.toChars());
        cost += COST_MAX; // default is we can't inline it
    }

    override void visit(ExpStatement s)
    {
        expressionInlineCost(s.exp);
    }

    override void visit(CompoundStatement s)
    {
        scope InlineCostVisitor icv = new InlineCostVisitor(this);
        foreach (i; 0 .. s.statements.dim)
        {
            Statement s2 = (*s.statements)[i];
            if (s2)
            {
                /* Specifically allow:
                 *  if (condition)
                 *      return exp1;
                 *  return exp2;
                 */
                IfStatement ifs;
                Statement s3;
                if ((ifs = s2.isIfStatement()) !is null &&
                    ifs.ifbody &&
                    ifs.ifbody.isReturnStatement() &&
                    !ifs.elsebody &&
                    i + 1 < s.statements.dim &&
                    (s3 = (*s.statements)[i + 1]) !is null &&
                    s3.isReturnStatement()
                   )
                {
                    if (ifs.prm)       // if variables are declared
                    {
                        cost = COST_MAX;
                        return;
                    }
                    expressionInlineCost(ifs.condition);
                    ifs.ifbody.accept(this);
                    s3.accept(this);
                }
                else
                    s2.accept(icv);
                if (tooCostly(icv.cost))
                    break;
            }
        }
        cost += icv.cost;
    }

    override void visit(UnrolledLoopStatement s)
    {
        scope InlineCostVisitor icv = new InlineCostVisitor(this);
        foreach (s2; *s.statements)
        {
            if (s2)
            {
                s2.accept(icv);
                if (tooCostly(icv.cost))
                    break;
            }
        }
        cost += icv.cost;
    }

    override void visit(ScopeStatement s)
    {
        cost++;
        if (s.statement)
            s.statement.accept(this);
    }

    override void visit(IfStatement s)
    {
        /* Can't declare variables inside ?: expressions, so
         * we cannot inline if a variable is declared.
         */
        if (s.prm)
        {
            cost = COST_MAX;
            return;
        }
        expressionInlineCost(s.condition);
        /* Specifically allow:
         *  if (condition)
         *      return exp1;
         *  else
         *      return exp2;
         * Otherwise, we can't handle return statements nested in if's.
         */
        if (s.elsebody && s.ifbody && s.ifbody.isReturnStatement() && s.elsebody.isReturnStatement())
        {
            s.ifbody.accept(this);
            s.elsebody.accept(this);
            //printf("cost = %d\n", cost);
        }
        else
        {
            nested += 1;
            if (s.ifbody)
                s.ifbody.accept(this);
            if (s.elsebody)
                s.elsebody.accept(this);
            nested -= 1;
        }
        //printf("IfStatement.inlineCost = %d\n", cost);
    }

    override void visit(ReturnStatement s)
    {
        // Can't handle return statements nested in if's
        if (nested)
        {
            cost = COST_MAX;
        }
        else
        {
            expressionInlineCost(s.exp);
        }
    }

    override void visit(ImportStatement s)
    {
    }

    override void visit(ForStatement s)
    {
        cost += STATEMENT_COST;
        if (s._init)
            s._init.accept(this);
        if (s.condition)
            s.condition.accept(this);
        if (s.increment)
            s.increment.accept(this);
        if (s._body)
            s._body.accept(this);
        //printf("ForStatement: inlineCost = %d\n", cost);
    }

    override void visit(ThrowStatement s)
    {
        cost += STATEMENT_COST;
        s.exp.accept(this);
    }

    /* -------------------------- */
    void expressionInlineCost(Expression e)
    {
        //printf("expressionInlineCost()\n");
        //e.print();
        if (e)
        {
            extern (C++) final class LambdaInlineCost : StoppableVisitor
            {
                alias visit = super.visit;
                InlineCostVisitor icv;

            public:
                extern (D) this(InlineCostVisitor icv)
                {
                    this.icv = icv;
                }

                override void visit(Expression e)
                {
                    e.accept(icv);
                    stop = icv.cost >= COST_MAX;
                }
            }

            scope InlineCostVisitor icv = new InlineCostVisitor(this);
            scope LambdaInlineCost lic = new LambdaInlineCost(icv);
            walkPostorder(e, lic);
            cost += icv.cost;
        }
    }

    override void visit(Expression e)
    {
        cost++;
    }

    override void visit(VarExp e)
    {
        //printf("VarExp.inlineCost3() %s\n", toChars());
        Type tb = e.type.toBasetype();
        if (tb.ty == Tstruct)
        {
            StructDeclaration sd = (cast(TypeStruct)tb).sym;
            if (sd.isNested())
            {
                /* An inner struct will be nested inside another function hierarchy than where
                 * we're inlining into, so don't inline it.
                 * At least not until we figure out how to 'move' the struct to be nested
                 * locally. Example:
                 *   struct S(alias pred) { void unused_func(); }
                 *   void abc() { int w; S!(w) m; }
                 *   void bar() { abc(); }
                 */
                cost = COST_MAX;
                return;
            }
        }
        FuncDeclaration fd = e.var.isFuncDeclaration();
        if (fd && fd.isNested()) // https://issues.dlang.org/show_bug.cgi?id=7199 for test case
            cost = COST_MAX;
        else
            cost++;
    }

    override void visit(ThisExp e)
    {
        //printf("ThisExp.inlineCost3() %s\n", toChars());
        if (!fd)
        {
            cost = COST_MAX;
            return;
        }
        if (!hdrscan)
        {
            if (fd.isNested() || !hasthis)
            {
                cost = COST_MAX;
                return;
            }
        }
        cost++;
    }

    override void visit(StructLiteralExp e)
    {
        //printf("StructLiteralExp.inlineCost3() %s\n", toChars());
        if (e.sd.isNested())
            cost = COST_MAX;
        else
            cost++;
    }

    override void visit(NewExp e)
    {
        //printf("NewExp.inlineCost3() %s\n", e.toChars());
        AggregateDeclaration ad = isAggregate(e.newtype);
        if (ad && ad.isNested())
            cost = COST_MAX;
        else
            cost++;
    }

    override void visit(FuncExp e)
    {
        //printf("FuncExp.inlineCost3()\n");
        // Right now, this makes the function be output to the .obj file twice.
        cost = COST_MAX;
    }

    override void visit(DelegateExp e)
    {
        //printf("DelegateExp.inlineCost3()\n");
        cost = COST_MAX;
    }

    override void visit(DeclarationExp e)
    {
        //printf("DeclarationExp.inlineCost3()\n");
        VarDeclaration vd = e.declaration.isVarDeclaration();
        if (vd)
        {
            TupleDeclaration td = vd.toAlias().isTupleDeclaration();
            if (td)
            {
                cost = COST_MAX; // finish DeclarationExp.doInlineAs
                return;
            }
            if (!hdrscan && vd.isDataseg())
            {
                cost = COST_MAX;
                return;
            }
            if (vd.edtor)
            {
                // if destructor required
                // needs work to make this work
                cost = COST_MAX;
                return;
            }
            // Scan initializer (vd.init)
            if (vd._init)
            {
                ExpInitializer ie = vd._init.isExpInitializer();
                if (ie)
                {
                    expressionInlineCost(ie.exp);
                }
            }
            cost += 1;
        }
        // These can contain functions, which when copied, get output twice.
        if (e.declaration.isStructDeclaration() || e.declaration.isClassDeclaration() || e.declaration.isFuncDeclaration() || e.declaration.isAttribDeclaration() || e.declaration.isTemplateMixin())
        {
            cost = COST_MAX;
            return;
        }
        //printf("DeclarationExp.inlineCost3('%s')\n", toChars());
    }

    override void visit(CallExp e)
    {
        //printf("CallExp.inlineCost3() %s\n", toChars());
        // https://issues.dlang.org/show_bug.cgi?id=3500
        // super.func() calls must be devirtualized, and the inliner
        // can't handle that at present.
        if (e.e1.op == TOKdotvar && (cast(DotVarExp)e.e1).e1.op == TOKsuper)
            cost = COST_MAX;
        else if (e.f && e.f.ident == Id.__alloca && e.f.linkage == LINKc && !allowAlloca)
            cost = COST_MAX; // inlining alloca may cause stack overflows
        else
            cost++;
    }
}

