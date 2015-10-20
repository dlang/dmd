/**
 * Compiler implementation of the D programming language
 *
 * Copyright: Copyright (c) 1999-2015 by Digital Mars, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC inline.d)
 */

module ddmd.inline;

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
import ddmd.dtemplate;
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

private:
enum LOG = false;
enum CANINLINE_LOG = false;

/* ========== Compute cost of inlining =============== */

/* Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */
enum COST_MAX = 250;
enum STATEMENT_COST = 0x1000;
enum STATEMENT_COST_MAX = 250 * 0x1000;

// STATEMENT_COST be power of 2 and greater than COST_MAX
//static assert((STATEMENT_COST & (STATEMENT_COST - 1)) == 0);
//static assert(STATEMENT_COST > COST_MAX);

bool tooCostly(int cost)
{
    return ((cost & (STATEMENT_COST - 1)) >= COST_MAX);
}

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
        if (fd && fd.isNested()) // see Bugzilla 7199 for test case
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
                cost = COST_MAX; // finish DeclarationExp.doInline
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
        // Bugzilla 3500: super.func() calls must be devirtualized, and the inliner
        // can't handle that at present.
        if (e.e1.op == TOKdotvar && (cast(DotVarExp)e.e1).e1.op == TOKsuper)
            cost = COST_MAX;
        else if (e.f && e.f.ident == Id.__alloca && e.f.linkage == LINKc && !allowAlloca)
            cost = COST_MAX; // inlining alloca may cause stack overflows
        else
            cost++;
    }
}

/* ======================== Perform the inlining ============================== */

/***********************************************************
 * Inlining is done by:
 * o    Converting to an Expression
 * o    Copying the trees of the function to be inlined
 * o    Renaming the variables
 */
final class InlineDoState
{
    // inline context
    VarDeclaration vthis;
    Dsymbols from;      // old Dsymbols
    Dsymbols to;        // parallel array of new Dsymbols
    Dsymbol parent;     // new parent
    FuncDeclaration fd; // function being inlined (old parent)
    // inline result
    bool foundReturn;

    this(Dsymbol parent, FuncDeclaration fd)
    {
        this.parent = parent;
        this.fd = fd;
    }
}

Statement inlineAsStatement(Statement s, InlineDoState ids)
{
    extern (C++) final class InlineAsStatement : Visitor
    {
        alias visit = super.visit;
    public:
        InlineDoState ids;
        Statement result;

        extern (D) this(InlineDoState ids)
        {
            this.ids = ids;
        }

        override void visit(Statement s)
        {
            assert(0); // default is we can't inline it
        }

        override void visit(ExpStatement s)
        {
            static if (LOG)
            {
                if (s.exp)
                    printf("ExpStatement.inlineAsStatement() '%s'\n", s.exp.toChars());
            }
            result = new ExpStatement(s.loc, s.exp ? doInline(s.exp, ids) : null);
        }

        override void visit(CompoundStatement s)
        {
            //printf("CompoundStatement.inlineAsStatement() %d\n", s.statements.dim);
            auto as = new Statements();
            as.reserve(s.statements.dim);
            foreach (sx; *s.statements)
            {
                if (sx)
                {
                    as.push(inlineAsStatement(sx, ids));
                    if (ids.foundReturn)
                        break;
                }
                else
                    as.push(null);
            }
            result = new CompoundStatement(s.loc, as);
        }

        override void visit(UnrolledLoopStatement s)
        {
            //printf("UnrolledLoopStatement.inlineAsStatement() %d\n", s.statements.dim);
            auto as = new Statements();
            as.reserve(s.statements.dim);
            foreach (sx; *s.statements)
            {
                if (sx)
                {
                    as.push(inlineAsStatement(sx, ids));
                    if (ids.foundReturn)
                        break;
                }
                else
                    as.push(null);
            }
            result = new UnrolledLoopStatement(s.loc, as);
        }

        override void visit(ScopeStatement s)
        {
            //printf("ScopeStatement.inlineAsStatement() %d\n", s.statement.dim);
            result = s.statement ? new ScopeStatement(s.loc, inlineAsStatement(s.statement, ids)) : s;
        }

        override void visit(IfStatement s)
        {
            assert(!s.prm);
            Expression condition = s.condition ? doInline(s.condition, ids) : null;
            Statement ifbody = s.ifbody ? inlineAsStatement(s.ifbody, ids) : null;
            bool bodyReturn = ids.foundReturn;
            ids.foundReturn = false;
            Statement elsebody = s.elsebody ? inlineAsStatement(s.elsebody, ids) : null;
            ids.foundReturn = ids.foundReturn && bodyReturn;
            result = new IfStatement(s.loc, s.prm, condition, ifbody, elsebody);
        }

        override void visit(ReturnStatement s)
        {
            //printf("ReturnStatement.inlineAsStatement() '%s'\n", s.exp ? s.exp.toChars() : "");
            ids.foundReturn = true;
            if (s.exp) // Bugzilla 14560: 'return' must not leave in the expand result
                result = new ReturnStatement(s.loc, doInline(s.exp, ids));
        }

        override void visit(ImportStatement s)
        {
            result = null;
        }

        override void visit(ForStatement s)
        {
            //printf("ForStatement.inlineAsStatement()\n");
            Statement _init = s._init ? inlineAsStatement(s._init, ids) : null;
            Expression condition = s.condition ? doInline(s.condition, ids) : null;
            Expression increment = s.increment ? doInline(s.increment, ids) : null;
            Statement _body = s._body ? inlineAsStatement(s._body, ids) : null;
            result = new ForStatement(s.loc, _init, condition, increment, _body, s.endloc);
        }

        override void visit(ThrowStatement s)
        {
            //printf("ThrowStatement.inlineAsStatement() '%s'\n", s.exp.toChars());
            result = new ThrowStatement(s.loc, doInline(s.exp, ids));
        }
    }

    scope InlineAsStatement v = new InlineAsStatement(ids);
    s.accept(v);
    return v.result;
}

/***********************************************************
 */
Expression doInline(Statement s, InlineDoState ids)
{
    extern (C++) final class InlineStatement : Visitor
    {
        alias visit = super.visit;
    public:
        InlineDoState ids;
        Expression result;

        extern (D) this(InlineDoState ids)
        {
            this.ids = ids;
        }

        override void visit(Statement s)
        {
            printf("Statement.doInline()\n%s\n", s.toChars());
            fflush(stdout);
            assert(0); // default is we can't inline it
        }

        override void visit(ExpStatement s)
        {
            static if (LOG)
            {
                if (s.exp)
                    printf("ExpStatement.doInline() '%s'\n", s.exp.toChars());
            }
            result = s.exp ? doInline(s.exp, ids) : null;
        }

        override void visit(CompoundStatement s)
        {
            //printf("CompoundStatement.doInline() %d\n", s.statements.dim);
            foreach (i; 0 .. s.statements.dim)
            {
                Statement sx = (*s.statements)[i];
                if (sx)
                {
                    /* Specifically allow:
                     *  if (condition)
                     *  return exp1;
                     *  return exp2;
                     */
                    IfStatement ifs;
                    Statement s3;
                    if ((ifs = sx.isIfStatement()) !is null &&
                        ifs.ifbody &&
                        ifs.ifbody.isReturnStatement() &&
                        !ifs.elsebody &&
                        i + 1 < s.statements.dim &&
                        (s3 = (*s.statements)[i + 1]) !is null &&
                        s3.isReturnStatement()
                       )
                    {
                        /* Rewrite as ?:
                         */
                        Expression econd = doInline(ifs.condition, ids);
                        assert(econd);
                        Expression e1 = doInline(ifs.ifbody, ids);
                        assert(ids.foundReturn);
                        Expression e2 = doInline(s3, ids);

                        Expression e = new CondExp(econd.loc, econd, e1, e2);
                        e.type = e1.type;
                        if (e.type.ty == Ttuple)
                        {
                            e1.type = Type.tvoid;
                            e2.type = Type.tvoid;
                            e.type = Type.tvoid;
                        }
                        result = Expression.combine(result, e);
                    }
                    else
                    {
                        Expression e = doInline(sx, ids);
                        result = Expression.combine(result, e);
                    }
                    if (ids.foundReturn)
                        break;
                }
            }
        }

        override void visit(UnrolledLoopStatement s)
        {
            //printf("UnrolledLoopStatement.doInline() %d\n", s.statements.dim);
            foreach (sx; *s.statements)
            {
                if (sx)
                {
                    Expression e = doInline(sx, ids);
                    result = Expression.combine(result, e);
                    if (ids.foundReturn)
                        break;
                }
            }
        }

        override void visit(ScopeStatement s)
        {
            result = s.statement ? doInline(s.statement, ids) : null;
        }

        override void visit(IfStatement s)
        {
            assert(!s.prm);
            Expression econd = doInline(s.condition, ids);
            assert(econd);
            Expression e1 = s.ifbody ? doInline(s.ifbody, ids) : null;
            bool bodyReturn = ids.foundReturn;
            ids.foundReturn = false;
            Expression e2 = s.elsebody ? doInline(s.elsebody, ids) : null;
            if (e1 && e2)
            {
                result = new CondExp(econd.loc, econd, e1, e2);
                result.type = e1.type;
                if (result.type.ty == Ttuple)
                {
                    e1.type = Type.tvoid;
                    e2.type = Type.tvoid;
                    result.type = Type.tvoid;
                }
            }
            else if (e1)
            {
                result = new AndAndExp(econd.loc, econd, e1);
                result.type = Type.tvoid;
            }
            else if (e2)
            {
                result = new OrOrExp(econd.loc, econd, e2);
                result.type = Type.tvoid;
            }
            else
            {
                result = econd;
            }
            ids.foundReturn = ids.foundReturn && bodyReturn;
        }

        override void visit(ReturnStatement s)
        {
            //printf("ReturnStatement.doInline() '%s'\n", s.exp ? s.exp.toChars() : "");
            ids.foundReturn = true;
            result = s.exp ? doInline(s.exp, ids) : null;
        }

        override void visit(ImportStatement s)
        {
        }
    }

    scope InlineStatement v = new InlineStatement(ids);
    s.accept(v);
    return v.result;
}

/***********************************************************
 */
Expression doInline(Expression e, InlineDoState ids)
{
    extern (C++) final class InlineExpression : Visitor
    {
        alias visit = super.visit;
    public:
        InlineDoState ids;
        Expression result;

        extern (D) this(InlineDoState ids)
        {
            this.ids = ids;
        }

        /******************************
         * Perform doInline() on an array of Expressions.
         */
        Expressions* arrayExpressiondoInline(Expressions* a)
        {
            if (!a)
                return null;
            auto newa = new Expressions();
            newa.setDim(a.dim);
            foreach (i;  0 .. a.dim)
            {
                Expression e = (*a)[i];
                if (e)
                    e = doInline(e, ids);
                (*newa)[i] = e;
            }
            return newa;
        }

        override void visit(Expression e)
        {
            //printf("Expression.doInline(%s): %s\n", Token.toChars(e.op), e.toChars());
            result = e.copy();
        }

        override void visit(SymOffExp e)
        {
            //printf("SymOffExp.doInline(%s)\n", e.toChars());
            foreach (i; 0 .. ids.from.dim)
            {
                if (e.var == ids.from[i])
                {
                    SymOffExp se = cast(SymOffExp)e.copy();
                    se.var = cast(Declaration)ids.to[i];
                    result = se;
                    return;
                }
            }
            result = e;
        }

        override void visit(VarExp e)
        {
            //printf("VarExp.doInline(%s)\n", e.toChars());
            foreach (i; 0 .. ids.from.dim)
            {
                if (e.var == ids.from[i])
                {
                    VarExp ve = cast(VarExp)e.copy();
                    ve.var = cast(Declaration)ids.to[i];
                    result = ve;
                    return;
                }
            }
            if (ids.fd && e.var == ids.fd.vthis)
            {
                result = new VarExp(e.loc, ids.vthis);
                result.type = e.type;
                return;
            }
            /* Inlining context pointer access for nested referenced variables.
             * For example:
             *      auto fun() {
             *        int i = 40;
             *        auto foo() {
             *          int g = 2;
             *          struct Result {
             *            auto bar() { return i + g; }
             *          }
             *          return Result();
             *        }
             *        return foo();
             *      }
             *      auto t = fun();
             * 'i' and 'g' are nested referenced variables in Result.bar(), so:
             *      auto x = t.bar();
             * should be inlined to:
             *      auto x = *(t.vthis.vthis + i.voffset) + *(t.vthis + g.voffset)
             */
            VarDeclaration v = e.var.isVarDeclaration();
            if (v && v.nestedrefs.dim && ids.vthis)
            {
                Dsymbol s = ids.fd;
                FuncDeclaration fdv = v.toParent().isFuncDeclaration();
                assert(fdv);
                result = new VarExp(e.loc, ids.vthis);
                result.type = ids.vthis.type;
                while (s != fdv)
                {
                    FuncDeclaration f = s.isFuncDeclaration();
                    if (AggregateDeclaration ad = s.isThis())
                    {
                        assert(ad.vthis);
                        result = new DotVarExp(e.loc, result, ad.vthis);
                        result.type = ad.vthis.type;
                        s = ad.toParent2();
                    }
                    else if (f && f.isNested())
                    {
                        assert(f.vthis);
                        if (f.hasNestedFrameRefs())
                        {
                            result = new DotVarExp(e.loc, result, f.vthis);
                            result.type = f.vthis.type;
                        }
                        s = f.toParent2();
                    }
                    else
                        assert(0);
                    assert(s);
                }
                result = new DotVarExp(e.loc, result, v);
                result.type = v.type;
                //printf("\t==> result = %s, type = %s\n", result.toChars(), result.type.toChars());
                return;
            }
            result = e;
        }

        override void visit(ThisExp e)
        {
            //if (!ids.vthis)
            //e.error("no 'this' when inlining %s", ids.parent.toChars());
            if (!ids.vthis)
            {
                result = e;
                return;
            }
            result = new VarExp(e.loc, ids.vthis);
            result.type = e.type;
        }

        override void visit(SuperExp e)
        {
            assert(ids.vthis);
            result = new VarExp(e.loc, ids.vthis);
            result.type = e.type;
        }

        override void visit(DeclarationExp e)
        {
            //printf("DeclarationExp.doInline(%s)\n", e.toChars());
            if (VarDeclaration vd = e.declaration.isVarDeclaration())
            {
                version (none)
                {
                    // Need to figure this out before inlining can work for tuples
                    TupleDeclaration td = vd.toAlias().isTupleDeclaration();
                    if (td)
                    {
                        foreach (i; 0 .. td.objects.dim)
                        {
                            DsymbolExp se = (*td.objects)[i];
                            assert(se.op == TOKdsymbol);
                            se.s;
                        }
                        result = st.objects.dim;
                        return;
                    }
                }
                if (!vd.isStatic())
                {
                    if (ids.fd && vd == ids.fd.nrvo_var)
                    {
                        foreach (i; 0 .. ids.from.dim)
                        {
                            if (vd == ids.from[i])
                            {
                                if (vd._init && !vd._init.isVoidInitializer())
                                {
                                    result = vd._init.toExpression();
                                    assert(result);
                                    result = doInline(result, ids);
                                }
                                else
                                    result = new IntegerExp(vd._init.loc, 0, Type.tint32);
                                return;
                            }
                        }
                    }
                    auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                    memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                    vto.parent = ids.parent;
                    vto.csym = null;
                    vto.isym = null;
                    ids.from.push(vd);
                    ids.to.push(vto);
                    if (vd._init)
                    {
                        if (vd._init.isVoidInitializer())
                        {
                            vto._init = new VoidInitializer(vd._init.loc);
                        }
                        else
                        {
                            Expression ei = vd._init.toExpression();
                            assert(ei);
                            vto._init = new ExpInitializer(ei.loc, doInline(ei, ids));
                        }
                    }
                    DeclarationExp de = cast(DeclarationExp)e.copy();
                    de.declaration = vto;
                    result = de;
                    return;
                }
            }
            /* This needs work, like DeclarationExp.toElem(), if we are
             * to handle TemplateMixin's. For now, we just don't inline them.
             */
            visit(cast(Expression)e);
        }

        override void visit(TypeidExp e)
        {
            //printf("TypeidExp.doInline(): %s\n", e.toChars());
            TypeidExp te = cast(TypeidExp)e.copy();
            if (Expression ex = isExpression(te.obj))
            {
                te.obj = doInline(ex, ids);
            }
            else
                assert(isType(te.obj));
            result = te;
        }

        override void visit(NewExp e)
        {
            //printf("NewExp.doInline(): %s\n", e.toChars());
            NewExp ne = cast(NewExp)e.copy();
            if (e.thisexp)
                ne.thisexp = doInline(e.thisexp, ids);
            ne.newargs = arrayExpressiondoInline(e.newargs);
            ne.arguments = arrayExpressiondoInline(e.arguments);
            result = ne;

            semanticTypeInfo(null, e.type);
        }

        override void visit(DeleteExp e)
        {
            visit(cast(UnaExp)e);
            Type tb = e.e1.type.toBasetype();
            if (tb.ty == Tarray)
            {
                Type tv = tb.nextOf().baseElemOf();
                if (tv.ty == Tstruct)
                {
                    TypeStruct ts = cast(TypeStruct)tv;
                    StructDeclaration sd = ts.sym;
                    if (sd.dtor)
                        semanticTypeInfo(null, ts);
                }
            }
        }

        override void visit(UnaExp e)
        {
            UnaExp ue = cast(UnaExp)e.copy();
            ue.e1 = doInline(e.e1, ids);
            result = ue;
        }

        override void visit(AssertExp e)
        {
            AssertExp ae = cast(AssertExp)e.copy();
            ae.e1 = doInline(e.e1, ids);
            if (e.msg)
                ae.msg = doInline(e.msg, ids);
            result = ae;
        }

        override void visit(BinExp e)
        {
            BinExp be = cast(BinExp)e.copy();
            be.e1 = doInline(e.e1, ids);
            be.e2 = doInline(e.e2, ids);
            result = be;
        }

        override void visit(CallExp e)
        {
            CallExp ce = cast(CallExp)e.copy();
            ce.e1 = doInline(e.e1, ids);
            ce.arguments = arrayExpressiondoInline(e.arguments);
            result = ce;
        }

        override void visit(AssignExp e)
        {
            visit(cast(BinExp)e);

            if (e.e1.op == TOKarraylength)
            {
                ArrayLengthExp ale = cast(ArrayLengthExp)e.e1;
                Type tn = ale.e1.type.toBasetype().nextOf();
                semanticTypeInfo(null, tn);
            }
        }

        override void visit(EqualExp e)
        {
            visit(cast(BinExp)e);

            Type t1 = e.e1.type.toBasetype();
            if (t1.ty == Tarray || t1.ty == Tsarray)
            {
                Type t = t1.nextOf().toBasetype();
                while (t.toBasetype().nextOf())
                    t = t.nextOf().toBasetype();
                if (t.ty == Tstruct)
                    semanticTypeInfo(null, t);
            }
            else if (t1.ty == Taarray)
            {
                semanticTypeInfo(null, t1);
            }
        }

        override void visit(IndexExp e)
        {
            IndexExp are = cast(IndexExp)e.copy();
            are.e1 = doInline(e.e1, ids);
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                VarDeclaration vd = e.lengthVar;
                auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                vto.parent = ids.parent;
                vto.csym = null;
                vto.isym = null;
                ids.from.push(vd);
                ids.to.push(vto);
                if (vd._init && !vd._init.isVoidInitializer())
                {
                    ExpInitializer ie = vd._init.isExpInitializer();
                    assert(ie);
                    vto._init = new ExpInitializer(ie.loc, doInline(ie.exp, ids));
                }
                are.lengthVar = vto;
            }
            are.e2 = doInline(e.e2, ids);
            result = are;
        }

        override void visit(SliceExp e)
        {
            SliceExp are = cast(SliceExp)e.copy();
            are.e1 = doInline(e.e1, ids);
            if (e.lengthVar)
            {
                //printf("lengthVar\n");
                VarDeclaration vd = e.lengthVar;
                auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
                memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
                vto.parent = ids.parent;
                vto.csym = null;
                vto.isym = null;
                ids.from.push(vd);
                ids.to.push(vto);
                if (vd._init && !vd._init.isVoidInitializer())
                {
                    ExpInitializer ie = vd._init.isExpInitializer();
                    assert(ie);
                    vto._init = new ExpInitializer(ie.loc, doInline(ie.exp, ids));
                }
                are.lengthVar = vto;
            }
            if (e.lwr)
                are.lwr = doInline(e.lwr, ids);
            if (e.upr)
                are.upr = doInline(e.upr, ids);
            result = are;
        }

        override void visit(TupleExp e)
        {
            TupleExp ce = cast(TupleExp)e.copy();
            if (e.e0)
                ce.e0 = doInline(e.e0, ids);
            ce.exps = arrayExpressiondoInline(e.exps);
            result = ce;
        }

        override void visit(ArrayLiteralExp e)
        {
            ArrayLiteralExp ce = cast(ArrayLiteralExp)e.copy();
            if (e.basis)
                ce.basis = doInline(e.basis, ids);
            ce.elements = arrayExpressiondoInline(e.elements);
            result = ce;

            semanticTypeInfo(null, e.type);
        }

        override void visit(AssocArrayLiteralExp e)
        {
            AssocArrayLiteralExp ce = cast(AssocArrayLiteralExp)e.copy();
            ce.keys = arrayExpressiondoInline(e.keys);
            ce.values = arrayExpressiondoInline(e.values);
            result = ce;

            semanticTypeInfo(null, e.type);
        }

        override void visit(StructLiteralExp e)
        {
            if (e.inlinecopy)
            {
                result = e.inlinecopy;
                return;
            }
            StructLiteralExp ce = cast(StructLiteralExp)e.copy();
            e.inlinecopy = ce;
            ce.elements = arrayExpressiondoInline(e.elements);
            e.inlinecopy = null;
            result = ce;
        }

        override void visit(ArrayExp e)
        {
            ArrayExp ce = cast(ArrayExp)e.copy();
            ce.e1 = doInline(e.e1, ids);
            ce.arguments = arrayExpressiondoInline(e.arguments);
            result = ce;
        }

        override void visit(CondExp e)
        {
            CondExp ce = cast(CondExp)e.copy();
            ce.econd = doInline(e.econd, ids);
            ce.e1 = doInline(e.e1, ids);
            ce.e2 = doInline(e.e2, ids);
            result = ce;
        }
    }

    scope InlineExpression v = new InlineExpression(ids);
    e.accept(v);
    return v.result;
}

/* ========== Walk the parse trees, and inline expand functions ============= */

/***********************************************************
 * Walk the trees, looking for functions to inline.
 * Inline any that can be.
 */
extern (C++) final class InlineScanVisitor : Visitor
{
    alias visit = super.visit;
public:
    FuncDeclaration parent;     // function being scanned
    // As the visit method cannot return a value, these variables
    // are used to pass the result from 'visit' back to 'inlineScan'
    Statement sresult;
    Expression eresult;
    bool again;

    extern (D) this()
    {
    }

    override void visit(Statement s)
    {
    }

    override void visit(ExpStatement s)
    {
        static if (LOG)
        {
            printf("ExpStatement.inlineScan(%s)\n", s.toChars());
        }
        if (s.exp)
        {
            inlineScan(s.exp);                 // inline as an expression
            /* If there's a TOKcall at the top, then it failed to inline
             * as an Expression. Try to inline as a Statement instead.
             * Note that inline scanning of s.exp.e1 and s.exp.arguments was already done.
             */
            if (s.exp && s.exp.op == TOKcall)
                visitCallExp(cast(CallExp)s.exp, null, true);
        }
    }

    override void visit(CompoundStatement s)
    {
        foreach (i; 0 .. s.statements.dim)
        {
            inlineScan((*s.statements)[i]);
        }
    }

    override void visit(UnrolledLoopStatement s)
    {
        foreach (i; 0 .. s.statements.dim)
        {
            inlineScan((*s.statements)[i]);
        }
    }

    override void visit(ScopeStatement s)
    {
        inlineScan(s.statement);
    }

    override void visit(WhileStatement s)
    {
        inlineScan(s.condition);
        inlineScan(s._body);
    }

    override void visit(DoStatement s)
    {
        inlineScan(s._body);
        inlineScan(s.condition);
    }

    override void visit(ForStatement s)
    {
        inlineScan(s._init);
        inlineScan(s.condition);
        inlineScan(s.increment);
        inlineScan(s._body);
    }

    override void visit(ForeachStatement s)
    {
        inlineScan(s.aggr);
        inlineScan(s._body);
    }

    override void visit(ForeachRangeStatement s)
    {
        inlineScan(s.lwr);
        inlineScan(s.upr);
        inlineScan(s._body);
    }

    override void visit(IfStatement s)
    {
        inlineScan(s.condition);
        inlineScan(s.ifbody);
        inlineScan(s.elsebody);
    }

    override void visit(SwitchStatement s)
    {
        //printf("SwitchStatement.inlineScan()\n");
        inlineScan(s.condition);
        inlineScan(s._body);
        Statement sdefault = s.sdefault;
        inlineScan(sdefault);
        s.sdefault = cast(DefaultStatement)sdefault;
        if (s.cases)
        {
            foreach (i; 0 .. s.cases.dim)
            {
                Statement scase = (*s.cases)[i];
                inlineScan(scase);
                (*s.cases)[i] = cast(CaseStatement)scase;
            }
        }
    }

    override void visit(CaseStatement s)
    {
        //printf("CaseStatement.inlineScan()\n");
        inlineScan(s.exp);
        inlineScan(s.statement);
    }

    override void visit(DefaultStatement s)
    {
        inlineScan(s.statement);
    }

    override void visit(ReturnStatement s)
    {
        //printf("ReturnStatement.inlineScan()\n");
        inlineScan(s.exp);
    }

    override void visit(SynchronizedStatement s)
    {
        inlineScan(s.exp);
        inlineScan(s._body);
    }

    override void visit(WithStatement s)
    {
        inlineScan(s.exp);
        inlineScan(s._body);
    }

    override void visit(TryCatchStatement s)
    {
        inlineScan(s._body);
        if (s.catches)
        {
            foreach (c; *s.catches)
            {
                inlineScan(c.handler);
            }
        }
    }

    override void visit(TryFinallyStatement s)
    {
        inlineScan(s._body);
        inlineScan(s.finalbody);
    }

    override void visit(ThrowStatement s)
    {
        inlineScan(s.exp);
    }

    override void visit(LabelStatement s)
    {
        inlineScan(s.statement);
    }

    /********************************
     * Scan Statement s for inlining opportunities,
     * and if found replace s with an inlined one.
     * Params:
     *  s = Statement to be scanned and updated
     */
    void inlineScan(ref Statement s)
    {
        if (!s)
            return;
        assert(sresult is null);
        s.accept(this);
        if (sresult)
        {
            s = sresult;
            sresult = null;
        }
    }

    /* -------------------------- */
    void arrayInlineScan(Expressions* arguments)
    {
        if (arguments)
        {
            foreach (i; 0 .. arguments.dim)
            {
                inlineScan((*arguments)[i]);
            }
        }
    }

    override void visit(Expression e)
    {
    }

    void scanVar(Dsymbol s)
    {
        //printf("scanVar(%s %s)\n", s.kind(), s.toPrettyChars());
        VarDeclaration vd = s.isVarDeclaration();
        if (vd)
        {
            TupleDeclaration td = vd.toAlias().isTupleDeclaration();
            if (td)
            {
                foreach (i; 0 .. td.objects.dim)
                {
                    DsymbolExp se = cast(DsymbolExp)(*td.objects)[i];
                    assert(se.op == TOKdsymbol);
                    scanVar(se.s); // TODO
                }
            }
            else if (vd._init)
            {
                if (ExpInitializer ie = vd._init.isExpInitializer())
                {
                    inlineScan(ie.exp);
                }
            }
        }
        else
        {
            s.accept(this);
        }
    }

    override void visit(DeclarationExp e)
    {
        //printf("DeclarationExp.inlineScan()\n");
        scanVar(e.declaration);
    }

    override void visit(UnaExp e)
    {
        inlineScan(e.e1);
    }

    override void visit(AssertExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.msg);
    }

    override void visit(BinExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.e2);
    }

    override void visit(AssignExp e)
    {
        // Look for NRVO, as inlining NRVO function returns require special handling
        if (e.op == TOKconstruct && e.e2.op == TOKcall)
        {
            CallExp ce = cast(CallExp)e.e2;
            if (ce.f && ce.f.nrvo_can && ce.f.nrvo_var) // NRVO
            {
                if (e.e1.op == TOKvar)
                {
                    /* Inlining:
                     *   S s = foo();   // initializing by rvalue
                     *   S s = S(1);    // constructor call
                     */
                    Declaration d = (cast(VarExp)e.e1).var;
                    if (d.storage_class & (STCout | STCref)) // refinit
                        goto L1;
                }
                else
                {
                    /* Inlining:
                     *   this.field = foo();   // inside constructor
                     */
                    inlineScan(e.e1);
                }
                inlineScan(ce.e1);
                arrayInlineScan(ce.arguments);
                visitCallExp(ce, e.e1, false);
                if (eresult)
                {
                    //printf("call with nrvo: %s ==> %s\n", e.toChars(), eresult.toChars());
                    return;
                }
            }
        }
    L1:
        visit(cast(BinExp)e);
    }

    override void visit(CallExp e)
    {
        inlineScan(e.e1);
        arrayInlineScan(e.arguments);
        visitCallExp(e, null, false);
    }

    /**************************************
     * Check function call to see if can be inlined,
     * and then inline it if it can.
     * Params:
     *  e = the function call
     *  eret = if !null, then this is the lvalue of the nrvo function result
     *  asStatements = if inline as statements rather than as an Expression
     */
    void visitCallExp(CallExp e, Expression eret, bool asStatements)
    {
        //printf("CallExp.inlineScan() %s\n", e.toChars());
        FuncDeclaration fd;
        if (e.e1.op == TOKvar)
        {
            VarExp ve = cast(VarExp)e.e1;
            fd = ve.var.isFuncDeclaration();
            if (fd && fd != parent && canInline(fd, false, false, asStatements))
            {
                expandInline(fd, parent, eret, null, e.arguments, asStatements, eresult, sresult, again);
            }
        }
        else if (e.e1.op == TOKdotvar)
        {
            DotVarExp dve = cast(DotVarExp)e.e1;
            fd = dve.var.isFuncDeclaration();
            if (fd && fd != parent && canInline(fd, true, false, asStatements))
            {
                if (dve.e1.op == TOKcall && dve.e1.type.toBasetype().ty == Tstruct)
                {
                    /* To create ethis, we'll need to take the address
                     * of dve.e1, but this won't work if dve.e1 is
                     * a function call.
                     */
                }
                else
                {
                    expandInline(fd, parent, eret, dve.e1, e.arguments, asStatements, eresult, sresult, again);
                }
            }
        }
        else if (e.e1.op == TOKstar &&
                 (cast(PtrExp)e.e1).e1.op == TOKvar)
        {
            /* See if calling function pointer, and that function pointer is only
             * assigned its _init.
             * If so, do 'copy propagation' of the _init value and try to inline it.
             */
            VarExp ve = cast(VarExp)(cast(PtrExp)e.e1).e1;
            VarDeclaration v = ve.var.isVarDeclaration();
            if (v && v._init && onlyOneAssign(v, parent))
            {
                //printf("init: %s\n", v._init.toChars());
                auto ei = v._init.isExpInitializer();
                if (ei && ei.exp.op == TOKblit)
                {
                    Expression e2 = (cast(AssignExp)ei.exp).e2;
                    if (e2.op == TOKsymoff)
                    {
                        auto se = cast(SymOffExp)e2;
                        fd = se.var.isFuncDeclaration();
                        if (fd && fd != parent && canInline(fd, false, false, asStatements))
                        {
                            expandInline(fd, parent, eret, null, e.arguments, asStatements, eresult, sresult, again);
                        }
                    }
                    else if (e2.op == TOKfunction)
                    {
                        auto fld = (cast(FuncExp)e2).fd;
                        assert(fld.tok == TOKfunction);
                        fd = fld;
                        if (fd && fd != parent && canInline(fd, false, false, asStatements))
                        {
                            expandInline(fd, parent, eret, null, e.arguments, asStatements, eresult, sresult, again);
                        }
                    }
                }
            }
        }
        else
            return;

        if (global.params.verbose && (eresult || sresult))
            fprintf(global.stdmsg, "inlined   %s =>\n          %s\n", fd.toPrettyChars(), parent.toPrettyChars());

        if (eresult && e.type.ty != Tvoid)
        {
            Expression ex = eresult;
            while (ex.op == TOKcomma)
            {
                ex.type = e.type;
                ex = (cast(CommaExp)ex).e2;
            }
            ex.type = e.type;
        }
    }

    override void visit(SliceExp e)
    {
        inlineScan(e.e1);
        inlineScan(e.lwr);
        inlineScan(e.upr);
    }

    override void visit(TupleExp e)
    {
        //printf("TupleExp.inlineScan()\n");
        inlineScan(e.e0);
        arrayInlineScan(e.exps);
    }

    override void visit(ArrayLiteralExp e)
    {
        //printf("ArrayLiteralExp.inlineScan()\n");
        inlineScan(e.basis);
        arrayInlineScan(e.elements);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        //printf("AssocArrayLiteralExp.inlineScan()\n");
        arrayInlineScan(e.keys);
        arrayInlineScan(e.values);
    }

    override void visit(StructLiteralExp e)
    {
        //printf("StructLiteralExp.inlineScan()\n");
        if (e.stageflags & stageInlineScan)
            return;
        int old = e.stageflags;
        e.stageflags |= stageInlineScan;
        arrayInlineScan(e.elements);
        e.stageflags = old;
    }

    override void visit(ArrayExp e)
    {
        //printf("ArrayExp.inlineScan()\n");
        inlineScan(e.e1);
        arrayInlineScan(e.arguments);
    }

    override void visit(CondExp e)
    {
        inlineScan(e.econd);
        inlineScan(e.e1);
        inlineScan(e.e2);
    }

    /********************************
     * Scan Expression e for inlining opportunities,
     * and if found replace e with an inlined one.
     * Params:
     *  e = Expression to be scanned and updated
     */
    void inlineScan(ref Expression e)
    {
        if (!e)
            return;
        assert(eresult is null);
        e.accept(this);
        if (eresult)
        {
            e = eresult;
            eresult = null;
        }
    }

    /*************************************
     * Look for function inlining possibilities.
     */
    override void visit(Dsymbol d)
    {
        // Most Dsymbols aren't functions
    }

    override void visit(FuncDeclaration fd)
    {
        static if (LOG)
        {
            printf("FuncDeclaration.inlineScan('%s')\n", fd.toPrettyChars());
        }
        if (fd.isUnitTestDeclaration() && !global.params.useUnitTests ||
            fd.flags & FUNCFLAGinlineScanned)
            return;
        if (fd.fbody && !fd.naked)
        {
            auto againsave = again;
            auto parentsave = parent;
            parent = fd;
            do
            {
                again = false;
                fd.inlineNest++;
                fd.flags |= FUNCFLAGinlineScanned;
                inlineScan(fd.fbody);
                fd.inlineNest--;
            }
            while (again);
            again = againsave;
            parent = parentsave;
        }
    }

    override void visit(AttribDeclaration d)
    {
        Dsymbols* decls = d.include(null, null);
        if (decls)
        {
            foreach (i; 0 .. decls.dim)
            {
                Dsymbol s = (*decls)[i];
                //printf("AttribDeclaration.inlineScan %s\n", s.toChars());
                s.accept(this);
            }
        }
    }

    override void visit(AggregateDeclaration ad)
    {
        //printf("AggregateDeclaration.inlineScan(%s)\n", toChars());
        if (ad.members)
        {
            foreach (i; 0 .. ad.members.dim)
            {
                Dsymbol s = (*ad.members)[i];
                //printf("inline scan aggregate symbol '%s'\n", s.toChars());
                s.accept(this);
            }
        }
    }

    override void visit(TemplateInstance ti)
    {
        static if (LOG)
        {
            printf("TemplateInstance.inlineScan('%s')\n", ti.toChars());
        }
        if (!ti.errors && ti.members)
        {
            foreach (i; 0 .. ti.members.dim)
            {
                Dsymbol s = (*ti.members)[i];
                s.accept(this);
            }
        }
    }
}

bool canInline(FuncDeclaration fd, bool hasthis, bool hdrscan, bool statementsToo)
{
    int cost;

    enum CANINLINE_LOG = 0;
    static if (CANINLINE_LOG)
    {
        printf("FuncDeclaration.canInline(hasthis = %d, statementsToo = %d, '%s')\n", hasthis, statementsToo, fd.toPrettyChars());
    }

    if (fd.needThis() && !hasthis)
        return false;

    if (fd.inlineNest)
    {
        static if (CANINLINE_LOG)
        {
            printf("\t1: no, inlineNest = %d, semanticRun = %d\n", fd.inlineNest, fd.semanticRun);
        }
        return false;
    }

    if (fd.semanticRun < PASSsemantic3 && !hdrscan)
    {
        if (!fd.fbody)
            return false;
        if (!fd.functionSemantic3())
            return false;
        Module.runDeferredSemantic3();
        if (global.errors)
            return false;
        assert(fd.semanticRun >= PASSsemantic3done);
    }

    switch (statementsToo ? fd.inlineStatusStmt : fd.inlineStatusExp)
    {
    case ILSyes:
        static if (CANINLINE_LOG)
        {
            printf("\t1: yes %s\n", fd.toChars());
        }
        return true;
    case ILSno:
        static if (CANINLINE_LOG)
        {
            printf("\t1: no %s\n", fd.toChars());
        }
        return false;
    case ILSuninitialized:
        break;
    default:
        assert(0);
    }

    switch (fd.inlining)
    {
    case PINLINEdefault:
        break;
    case PINLINEalways:
        break;
    case PINLINEnever:
        return false;
    default:
        assert(0);
    }

    if (fd.type)
    {
        assert(fd.type.ty == Tfunction);
        TypeFunction tf = cast(TypeFunction)fd.type;

        // no variadic parameter lists
        if (tf.varargs == 1)
            goto Lno;

        /* Don't inline a function that returns non-void, but has
         * no return expression.
         * No statement inlining for non-voids.
         */
        if (tf.next && tf.next.ty != Tvoid &&
            (!(fd.hasReturnExp & 1) || statementsToo) &&
            !hdrscan)
        {
            goto Lno;
        }

        /* Bugzilla 14560: If fd returns void, all explicit `return;`s
         * must not appear in the expanded result.
         * See also ReturnStatement.inlineAsStatement().
         */
    }

    // cannot inline constructor calls because we need to convert:
    //      return;
    // to:
    //      return this;
    // ensure() has magic properties the inliner loses
    // require() has magic properties too
    // see bug 7699
    // no nested references to this frame
    if (!fd.fbody ||
        fd.ident == Id.ensure ||
        (fd.ident == Id.require &&
         fd.toParent().isFuncDeclaration() &&
         fd.toParent().isFuncDeclaration().needThis()) ||
        !hdrscan && (fd.isSynchronized() ||
                     fd.isImportedSymbol() ||
                     fd.hasNestedFrameRefs() ||
                     (fd.isVirtual() && !fd.isFinalFunc())))
    {
        goto Lno;
    }

    {
        scope InlineCostVisitor icv = new InlineCostVisitor();
        icv.hasthis = hasthis;
        icv.fd = fd;
        icv.hdrscan = hdrscan;
        fd.fbody.accept(icv);
        cost = icv.cost;
    }
    static if (CANINLINE_LOG)
    {
        printf("cost = %d for %s\n", cost, fd.toChars());
    }

    if (tooCostly(cost))
        goto Lno;
    if (!statementsToo && cost > COST_MAX)
        goto Lno;

    if (!hdrscan)
    {
        // Don't modify inlineStatus for header content scan
        if (statementsToo)
            fd.inlineStatusStmt = ILSyes;
        else
            fd.inlineStatusExp = ILSyes;

        scope InlineScanVisitor v = new InlineScanVisitor();
        fd.accept(v); // Don't scan recursively for header content scan

        if (fd.inlineStatusExp == ILSuninitialized)
        {
            // Need to redo cost computation, as some statements or expressions have been inlined
            scope InlineCostVisitor icv = new InlineCostVisitor();
            icv.hasthis = hasthis;
            icv.fd = fd;
            icv.hdrscan = hdrscan;
            fd.fbody.accept(icv);
            cost = icv.cost;
            static if (CANINLINE_LOG)
            {
                printf("recomputed cost = %d for %s\n", cost, fd.toChars());
            }

            if (tooCostly(cost))
                goto Lno;
            if (!statementsToo && cost > COST_MAX)
                goto Lno;

            if (statementsToo)
                fd.inlineStatusStmt = ILSyes;
            else
                fd.inlineStatusExp = ILSyes;
        }
    }
    static if (CANINLINE_LOG)
    {
        printf("\t2: yes %s\n", fd.toChars());
    }
    return true;

Lno:
    if (fd.inlining == PINLINEalways)
        fd.error("cannot inline function");

    if (!hdrscan) // Don't modify inlineStatus for header content scan
    {
        if (statementsToo)
            fd.inlineStatusStmt = ILSno;
        else
            fd.inlineStatusExp = ILSno;
    }
    static if (CANINLINE_LOG)
    {
        printf("\t2: no %s\n", fd.toChars());
    }
    return false;
}

/**************************
 * Scan function implementations in Module m looking for functions that can be inlined,
 * and inline them in situ.
 *
 * Params:
 *    m = module to scan
 */
public void inlineScanModule(Module m)
{
    if (m.semanticRun != PASSsemantic3done)
        return;
    m.semanticRun = PASSinline;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.

    //printf("Module = %p\n", m.sc.scopesym);

    foreach (i; 0 .. m.members.dim)
    {
        Dsymbol s = (*m.members)[i];
        //if (global.params.verbose)
        //    fprintf(global.stdmsg, "inline scan symbol %s\n", s.toChars());
        scope InlineScanVisitor v = new InlineScanVisitor();
        s.accept(v);
    }
    m.semanticRun = PASSinlinedone;
}

/********************************************
 * Expand a function call inline,
 *      ethis.fd(arguments)
 *
 * Params:
 *      fd = function to expand
 *      parent = function that the call to fd is being expanded into
 *      eret = expression describing the lvalue of where the return value goes
 *      ethis = 'this' reference
 *      arguments = arguments passed to fd
 *      asStatements = expand to Statements rather than Expressions
 *      eresult = if expanding to an expression, this is where the expression is written to
 *      sresult = if expanding to a statement, this is where the statement is written to
 *      again = if true, then fd can be inline scanned again because there may be
 *           more opportunities for inlining
 * Returns:
 *      Expression it expanded to (null if ps is not null)
 */
void expandInline(FuncDeclaration fd, FuncDeclaration parent, Expression eret,
        Expression ethis, Expressions* arguments, bool asStatements,
        out Expression eresult, out Statement sresult, out bool again)
{
    Expression e = null;
    Statements* as = null;
    TypeFunction tf = cast(TypeFunction)fd.type;
    static if (LOG || CANINLINE_LOG)
    {
        printf("FuncDeclaration.expandInline('%s')\n", fd.toChars());
    }
    scope ids = new InlineDoState(parent, fd);

    if (asStatements)
        as = new Statements();

    VarDeclaration vret = null;
    if (eret)
    {
        if (eret.op == TOKvar)
        {
            vret = (cast(VarExp)eret).var.isVarDeclaration();
            assert(!(vret.storage_class & (STCout | STCref)));
        }
        else
        {
            /* Inlining:
             *   this.field = foo();   // inside constructor
             */
            vret = new VarDeclaration(fd.loc, eret.type, Identifier.generateId("_satmp"), null);
            vret.storage_class |= STCtemp | STCforeach | STCref;
            vret.linkage = LINKd;
            vret.parent = parent;

            Expression de = new DeclarationExp(fd.loc, vret);
            de.type = Type.tvoid;
            e = Expression.combine(e, de);

            Expression ex = new VarExp(fd.loc, vret);
            ex.type = vret.type;
            ex = new ConstructExp(fd.loc, ex, eret);
            ex.type = vret.type;
            e = Expression.combine(e, ex);
        }
    }

    // Set up vthis
    if (ethis)
    {
        if (ethis.type.ty == Tpointer)
        {
            Type t = ethis.type.nextOf();
            ethis = new PtrExp(ethis.loc, ethis);
            ethis.type = t;
        }
        auto ei = new ExpInitializer(ethis.loc, ethis);

        auto vthis = new VarDeclaration(ethis.loc, ethis.type, Id.This, ei);
        if (ethis.type.ty != Tclass)
            vthis.storage_class = STCref;
        else
            vthis.storage_class = STCin;
        vthis.linkage = LINKd;
        vthis.parent = parent;

        auto ve = new VarExp(vthis.loc, vthis);
        ve.type = vthis.type;

        ei.exp = new AssignExp(vthis.loc, ve, ethis);
        ei.exp.type = ve.type;
        if (ethis.type.ty != Tclass)
        {
            /* This is a reference initialization, not a simple assignment.
             */
            ei.exp.op = TOKconstruct;
        }

        ids.vthis = vthis;
    }

    // Set up parameters
    if (ethis)
    {
        Expression de = new DeclarationExp(Loc(), ids.vthis);
        de.type = Type.tvoid;
        e = Expression.combine(e, de);
    }

    if (!asStatements && fd.nrvo_var)
    {
        if (vret)
        {
            ids.from.push(fd.nrvo_var);
            ids.to.push(vret);
        }
        else
        {
            Identifier tmp = Identifier.generateId("__nrvoretval");
            auto vd = new VarDeclaration(fd.loc, fd.nrvo_var.type, tmp, null);
            assert(!tf.isref);
            vd.storage_class = STCtemp | STCrvalue;
            vd.linkage = tf.linkage;
            vd.parent = parent;

            ids.from.push(fd.nrvo_var);
            ids.to.push(vd);

            Expression de = new DeclarationExp(Loc(), vd);
            de.type = Type.tvoid;
            e = Expression.combine(e, de);
        }
    }
    if (arguments && arguments.dim)
    {
        assert(fd.parameters.dim == arguments.dim);
        foreach (i; 0 .. arguments.dim)
        {
            auto vfrom = (*fd.parameters)[i];

            auto arg = (*arguments)[i];
            auto ei = new ExpInitializer(arg.loc, arg);

            auto vto = new VarDeclaration(vfrom.loc, vfrom.type, vfrom.ident, ei);
            vto.storage_class |= vfrom.storage_class & (STCtemp | STCin | STCout | STClazy | STCref);
            vto.linkage = vfrom.linkage;
            vto.parent = parent;
            //printf("vto = '%s', vto.storage_class = x%x\n", vto.toChars(), vto.storage_class);
            //printf("vto.parent = '%s'\n", parent.toChars());

            auto ve = new VarExp(vto.loc, vto);
            //ve.type = vto.type;
            ve.type = arg.type;

            if (vfrom.storage_class & (STCout | STCref))
                ei.exp = new ConstructExp(vto.loc, ve, arg);
            else
                ei.exp = new BlitExp(vto.loc, ve, arg);
            ei.exp.type = ve.type;
            //ve.type.print();
            //arg.type.print();
            //ei.exp.print();

            ids.from.push(vfrom);
            ids.to.push(vto);

            auto de = new DeclarationExp(Loc(), vto);
            de.type = Type.tvoid;
            e = Expression.combine(e, de);

            /* If function pointer or delegate parameters are present,
             * inline scan again because if they are initialized to a symbol,
             * any calls to the fp or dg can be inlined.
             */
            if (vfrom.type.ty == Tdelegate ||
                vfrom.type.ty == Tpointer && vfrom.type.nextOf().ty == Tfunction)
            {
                again = true;
            }
        }
    }

    if (asStatements)
    {
        if (e)
        {
            as.push(new ExpStatement(Loc(), e));
            e = null;
        }
        fd.inlineNest++;
        Statement s = inlineAsStatement(fd.fbody, ids);
        as.push(s);
        sresult = new ScopeStatement(Loc(), new CompoundStatement(Loc(), as));
        fd.inlineNest--;
    }
    else
    {
        fd.inlineNest++;
        Expression eb = doInline(fd.fbody, ids);
        e = Expression.combine(e, eb);
        fd.inlineNest--;
        //eb.type.print();
        //eb.print();
        //eb.print();

        // Bugzilla 11322:
        if (tf.isref)
            e = e.toLvalue(null, null);

        /* There's a problem if what the function returns is used subsequently as an
         * lvalue, as in a struct return that is then used as a 'this'.
         * If we take the address of the return value, we will be taking the address
         * of the original, not the copy. Fix this by assigning the return value to
         * a temporary, then returning the temporary. If the temporary is used as an
         * lvalue, it will work.
         * This only happens with struct returns.
         * See Bugzilla 2127 for an example.
         *
         * On constructor call making __inlineretval is merely redundant, because
         * the returned reference is exactly same as vthis, and the 'this' variable
         * already exists at the caller side.
         */
        if (tf.next.ty == Tstruct && !fd.nrvo_var && !fd.isCtorDeclaration())
        {
            /* Generate a new variable to hold the result and initialize it with the
             * inlined body of the function:
             *   tret __inlineretval = e;
             */
            auto ei = new ExpInitializer(fd.loc, e);

            Identifier tmp = Identifier.generateId("__inlineretval");
            auto vd = new VarDeclaration(fd.loc, tf.next, tmp, ei);
            vd.storage_class = (tf.isref ? STCref : 0) | STCtemp | STCrvalue;
            vd.linkage = tf.linkage;
            vd.parent = parent;

            auto ve = new VarExp(fd.loc, vd);
            ve.type = tf.next;

            ei.exp = new ConstructExp(fd.loc, ve, e);
            ei.exp.type = ve.type;

            auto de = new DeclarationExp(Loc(), vd);
            de.type = Type.tvoid;

            // Chain the two together:
            //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
            e = Expression.combine(de, ve);

            //fprintf(stderr, "CallExp.inlineScan: e = "); e.print();
        }
        eresult = e;
    }
    //printf("%s.expandInline = { %s }\n", fd.toChars(), e.toChars());

    // Need to reevaluate whether parent can now be inlined
    // in expressions, as we might have inlined statements
    parent.inlineStatusExp = ILSuninitialized;
}

/****************************************************
 * Perform the "inline copying" of a default argument for a function parameter.
 */
public Expression inlineCopy(Expression e, Scope* sc)
{
    /* See Bugzilla 2935 for explanation of why just a copy() is broken
     */
    //return e.copy();
    if (e.op == TOKdelegate)
    {
        DelegateExp de = cast(DelegateExp)e;
        if (de.func.isNested())
        {
            /* See Bugzilla 4820
             * Defer checking until later if we actually need the 'this' pointer
             */
            return de.copy();
        }
    }
    scope InlineCostVisitor icv = new InlineCostVisitor();
    icv.hdrscan = 1;
    icv.allowAlloca = true;
    icv.expressionInlineCost(e);
    int cost = icv.cost;
    if (cost >= COST_MAX)
    {
        e.error("cannot inline default argument %s", e.toChars());
        return new ErrorExp();
    }
    scope ids = new InlineDoState(sc.parent, null);
    return doInline(e, ids);
}

/*************************************
 * Determine if v is 'head const', meaning
 * that once it is initialized it is not changed
 * again.
 *
 * This is done using a primitive flow analysis.
 *
 * v is head const if v is const or immutable.
 * Otherwise, v is assumed to be head const unless one of the
 * following is true:
 *      1. v is a `ref` or `out` variable
 *      2. v is a parameter and fd is a variadic function
 *      3. v is assigned to again
 *      4. the address of v is taken
 *      5. v is referred to by a function nested within fd
 *      6. v is ever assigned to a `ref` or `out` variable
 *      7. v is ever passed to another function as `ref` or `out`
 *
 * Params:
 *      v       variable to check
 *      fd      function that v is local to
 * Returns:
 *      true if v's initializer is the only value assigned to v
 */

bool onlyOneAssign(VarDeclaration v, FuncDeclaration fd)
{
    if (!v.type.isMutable())
        return true;            // currently the only case handled atm
    return false;
}

