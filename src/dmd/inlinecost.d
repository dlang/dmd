/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/inlinecost.d, _inlinecost.d)
 * Documentation:  https://dlang.org/phobos/dmd_inlinecost.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/inlinecost.d
 */

module dmd.inlinecost;

import core.stdc.stdio;
import core.stdc.string;

import dmd.aggregate;
import dmd.apply;
import dmd.arraytypes;
import dmd.attrib;
import dmd.dclass;
import dmd.declaration;
import dmd.dmodule;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.opover;
import dmd.statement;
import dmd.tokens;
import dmd.visitor;

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
 *      hasthis = if the function call has explicit 'this' expression
 *      hdrscan = if generating a header file
 * Returns:
 *      cost of inlining fd
 */
int inlineCostFunction(FuncDeclaration fd, bool hasthis, bool hdrscan)
{
    scope InlineCostVisitor icv = new InlineCostVisitor(hasthis, hdrscan, false, fd);
    fd.fbody.accept(icv);
    return icv.cost;
}

/**
 * Indicates if a nested aggregate prevents or not a function to be inlined.
 * It's used to compute the cost but also to avoid a copy of the aggregate
 * while the inliner processes.
 *
 * Params:
 *      e = the declaration expression that may represent an aggregate.
 *
 * Returns: `null` if `e` is not an aggregate or if it is an aggregate that
 *      doesn't permit inlining, and the aggregate otherwise.
 */
AggregateDeclaration isInlinableNestedAggregate(DeclarationExp e)
{
    AggregateDeclaration result;
    if (e.declaration.isAnonymous() && e.declaration.isAttribDeclaration)
    {
        AttribDeclaration ad = e.declaration.isAttribDeclaration;
        if (ad.decl.dim == 1)
        {
            if ((result = (*ad.decl)[0].isAggregateDeclaration) !is null)
            {
                // classes would have to be destroyed
                if (auto cdecl = result.isClassDeclaration)
                    return null;
                // if it's a struct: must not have dtor
                StructDeclaration sdecl = result.isStructDeclaration;
                if (sdecl && (sdecl.fieldDtor || sdecl.dtor))
                    return null;
                // the aggregate must be static
                UnionDeclaration udecl = result.isUnionDeclaration;
                if ((sdecl || udecl) && !(result.storage_class & STC.static_))
                    return null;

                return result;
            }
        }
    }
    else if ((result = e.declaration.isStructDeclaration) !is null)
    {
        return result;
    }
    else if ((result = e.declaration.isUnionDeclaration) !is null)
    {
        return result;
    }
    return null;
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
    alias visit = Visitor.visit;
public:
    bool hasthis;
    bool hdrscan;       // if inline scan for 'header' content
    bool allowAlloca;
    FuncDeclaration fd;
    int cost;           // zero start for subsequent AST
    bool foundReturn;

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
        icv.visitCompoundStatement(s);

        cost += icv.cost;
        foundReturn = icv.foundReturn;
    }

    /**
     * Compute cost of inlining a list of statements
     * Params:
     *  s = the statement list
     *  pos = the position in the compound list to start scan from
     */
    private void visitCompoundStatement(CompoundStatement s, size_t pos = 0)
    {
        foreach (i; pos .. s.statements.dim)
        {
            Statement sx = (*s.statements)[i];
            if (!sx)
                continue;

            if (auto ifs = sx.isIfStatement())
            {
                scope InlineCostVisitor icv = new InlineCostVisitor(this);
                bool subseqIsVisited = false;

                /* Scan if statement. A delegate is passed that continues scanning the
                 * rest of this compound statement if needed.
                 */
                icv.visitIfStatement(ifs, (v)
                {
                    subseqIsVisited = true;
                    v.visitCompoundStatement(s, i + 1);
                });
                cost += icv.cost;
                foundReturn = icv.foundReturn;

                if (subseqIsVisited || icv.foundReturn)
                    break;  // no need to visit statements[i+1 .. $].
                continue;
            }

            sx.accept(this);
            if (tooCostly(cost) || foundReturn)
                break;
        }
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
        visitIfStatement(s);
    }

    /**
     * Compute cost of inlining an if condition statement
     * Params:
     *  s = the if statement
     *  visitSubseq = callback for scanning subsequent statements
     */
    extern (D) private void visitIfStatement(IfStatement s, void delegate(InlineCostVisitor) visitSubseq = null)
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

        if (s.ifbody)
            s.ifbody.accept(this);
        bool thenReturn = foundReturn;
        foundReturn = false;

        if (s.elsebody)
            s.elsebody.accept(this);
        bool elseReturn = foundReturn;
        foundReturn = false;

        if (thenReturn != elseReturn && visitSubseq)
        {
            /* Recognize:
             *  if (condition) { ...; } else { ...; return exp2; }
             *  ...; return exp1;   // subsequent of 'then'.
             *
             * and:
             *  if (condition) { ...; return exp1; } else { ...; }
             *  ...; return exp2;   // subsequent of 'else'.
             */
            scope InlineCostVisitor v = new InlineCostVisitor();
            visitSubseq(v);
            cost += v.cost;
            if (!thenReturn)
                thenReturn = v.foundReturn;
            else
                elseReturn = v.foundReturn;
        }
        foundReturn = thenReturn && elseReturn;

        if (thenReturn != elseReturn)
        {
            // If ReturnStatement exists in one or other branch,
            // ifs cannot be inlined as Expression.
            cost = COST_MAX;
        }
    }

    override void visit(ReturnStatement s)
    {
        foundReturn = true;
        expressionInlineCost(s.exp);
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
                alias visit = typeof(super).visit;
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

        // aggregates are accepted under certain circumstances
        if (isInlinableNestedAggregate(e))
        {
            cost++;
            return;
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
        if (e.e1.op == TOK.dotVariable && (cast(DotVarExp)e.e1).e1.op == TOK.super_)
            cost = COST_MAX;
        else if (e.f && e.f.ident == Id.__alloca && e.f.linkage == LINK.c && !allowAlloca)
            cost = COST_MAX; // inlining alloca may cause stack overflows
        else
            cost++;
    }
}

